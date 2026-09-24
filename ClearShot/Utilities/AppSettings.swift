import SwiftUI
import ServiceManagement

enum ScreenshotFormat: String, CaseIterable, Codable, Identifiable {
    case png, jpeg, tiff, heic
    var id: String { rawValue }
    var displayName: String { rawValue.uppercased() }
    var fileExtension: String { self == .jpeg ? "jpg" : rawValue }
}

enum DefaultSaveBehavior: String, CaseIterable, Codable, Identifiable {
    case showResultWindow
    case saveImmediately
    case copyImmediately
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .showResultWindow: return "Show Preview & Actions"
        case .saveImmediately: return "Save to Default Location"
        case .copyImmediately: return "Copy to Clipboard"
        }
    }
}

enum AppAppearance: String, CaseIterable, Codable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Single source of truth for user preferences. Uses `@AppStorage`-compatible
/// `UserDefaults` under the hood but exposes strongly-typed values (shortcuts,
/// enums, retention policy) so the rest of the app never touches raw keys.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    private init() {
        migrateDefaultsIfNeeded()
    }

    // MARK: - General

    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                ErrorPresenter.shared.present(error)
            }
        }
    }

    @Published var showMenuBarIcon: Bool = true
    @Published var screenshotFormat: ScreenshotFormat = .png
    @Published var defaultSaveBehavior: DefaultSaveBehavior = .showResultWindow
    @Published var defaultSaveLocation: URL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser

    // MARK: - Appearance

    @Published var appearance: AppAppearance = .system
    @Published var animationsEnabled: Bool = true

    // MARK: - History

    @Published var historyRetention: HistoryRetention = .lastN(50) {
        didSet { ScreenshotHistoryStore.shared.enforceRetentionPolicy() }
    }

    // MARK: - Shortcuts

    @Published var activationShortcut: KeyboardShortcutSpec = .init(keyCode: 49, modifiers: [.command, .shift]) // Cmd+Shift+Space
    @Published var fullScreenShortcut: KeyboardShortcutSpec = .init(keyCode: 20, modifiers: [.command, .shift]) // Cmd+Shift+3
    @Published var regionShortcut: KeyboardShortcutSpec = .init(keyCode: 21, modifiers: [.command, .shift])     // Cmd+Shift+4
    @Published var windowShortcut: KeyboardShortcutSpec = .init(keyCode: 23, modifiers: [.command, .shift, .control]) // Cmd+Shift+Ctrl+5

    // MARK: - Provider config persistence

    func loadProviderConfig(for id: AIProviderID) -> AIProviderConfig? {
        guard let data = defaults.data(forKey: "provider.config.\(id.rawValue)") else { return nil }
        return try? JSONDecoder().decode(AIProviderConfig.self, from: data)
    }

    func saveProviderConfig(_ config: AIProviderConfig, for id: AIProviderID) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: "provider.config.\(id.rawValue)")
    }

    private func migrateDefaultsIfNeeded() {
        // Reserved for future settings-schema migrations.
    }
}
