import AppKit
import Combine

/// Persists screenshot history to `~/Library/Application Support/ClearShot/History`.
/// Each entry is a PNG plus one shared JSON index file — deliberately avoiding
/// a database dependency for something this small.
@MainActor
final class ScreenshotHistoryStore: ObservableObject {
    static let shared = ScreenshotHistoryStore()

    @Published private(set) var items: [ScreenshotHistoryItem] = []

    private let fileManager = FileManager.default
    private lazy var directory: URL = {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ClearShot/History", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    private var indexURL: URL { directory.appendingPathComponent("index.json") }

    private init() {
        loadIndex()
        enforceRetentionPolicy()
    }

    func add(_ screenshot: CapturedScreenshot) {
        guard AppSettings.shared.historyRetention != .off else { return }
        guard let png = screenshot.image.pngRepresentation else { return }

        let fileName = "\(screenshot.id.uuidString).png"
        let fileURL = directory.appendingPathComponent(fileName)
        try? png.write(to: fileURL)

        let item = ScreenshotHistoryItem(
            id: screenshot.id,
            fileName: fileName,
            modeDescription: screenshot.mode.displayName,
            capturedAt: screenshot.capturedAt
        )
        items.insert(item, at: 0)
        saveIndex()
        enforceRetentionPolicy()
    }

    func image(for item: ScreenshotHistoryItem) -> NSImage? {
        NSImage(contentsOf: directory.appendingPathComponent(item.fileName))
    }

    func delete(_ item: ScreenshotHistoryItem) {
        try? fileManager.removeItem(at: directory.appendingPathComponent(item.fileName))
        items.removeAll { $0.id == item.id }
        saveIndex()
    }

    func clearAll() {
        for item in items { try? fileManager.removeItem(at: directory.appendingPathComponent(item.fileName)) }
        items.removeAll()
        saveIndex()
    }

    func fileURL(for item: ScreenshotHistoryItem) -> URL {
        directory.appendingPathComponent(item.fileName)
    }

    // MARK: - Retention

    /// Called on launch and after every insert; trims by count or age
    /// depending on the user's chosen policy in Settings → General.
    func enforceRetentionPolicy() {
        switch AppSettings.shared.historyRetention {
        case .off:
            clearAll()
        case .lastN(let count):
            guard items.count > count else { return }
            let toRemove = items.suffix(from: count)
            toRemove.forEach { try? fileManager.removeItem(at: directory.appendingPathComponent($0.fileName)) }
            items = Array(items.prefix(count))
            saveIndex()
        case .days(let days):
            let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
            let (keep, drop) = items.reduce(into: ([ScreenshotHistoryItem](), [ScreenshotHistoryItem]())) { result, item in
                if item.capturedAt >= cutoff { result.0.append(item) } else { result.1.append(item) }
            }
            drop.forEach { try? fileManager.removeItem(at: directory.appendingPathComponent($0.fileName)) }
            items = keep
            saveIndex()
        case .unlimited:
            break
        }
    }

    // MARK: - Persistence

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        items = (try? JSONDecoder().decode([ScreenshotHistoryItem].self, from: data)) ?? []
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: indexURL)
    }
}

enum HistoryRetention: Codable, Equatable {
    case off
    case lastN(Int)
    case days(Int)
    case unlimited

    var label: String {
        switch self {
        case .off: return "Don't Keep History"
        case .lastN(let n): return "Last \(n) Screenshots"
        case .days(let d): return "Last \(d) Days"
        case .unlimited: return "Keep Forever"
        }
    }

    static let allCases: [HistoryRetention] = [.off, .lastN(20), .lastN(50), .days(7), .days(30), .unlimited]
}
