import AppKit

/// An in-memory screenshot plus the metadata needed to persist it to history
/// and to re-derive a file URL when the user chooses to save it.
struct CapturedScreenshot: Identifiable {
    let id: UUID
    let image: NSImage
    let mode: CaptureMode
    let capturedAt: Date

    init(id: UUID = UUID(), image: NSImage, mode: CaptureMode, capturedAt: Date = Date()) {
        self.id = id
        self.image = image
        self.mode = mode
        self.capturedAt = capturedAt
    }

    var suggestedFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "ClearShot \(formatter.string(from: capturedAt))"
    }
}

/// Lightweight, `Codable` record persisted to disk for the History feature.
/// The full-resolution image lives alongside it as a file; this struct only
/// carries what's needed to list, thumbnail, and re-load it.
struct ScreenshotHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    let modeDescription: String
    let capturedAt: Date

    static func == (lhs: ScreenshotHistoryItem, rhs: ScreenshotHistoryItem) -> Bool {
        lhs.id == rhs.id
    }
}
