import Foundation
import Combine

/// Central registry of AI providers. Adding a new provider means:
///   1. Add a case to `AIProviderID`.
///   2. Implement `AIProvider`.
///   3. Register an instance in `init()`.
/// Nothing else in the app needs to change — Settings, the result UI, and
/// the prompt sheet all work against the `AIProvider` protocol.
@MainActor
final class AIProviderManager: ObservableObject {
    static let shared = AIProviderManager()

    @Published private(set) var providers: [AIProviderID: AIProvider] = [:]
    @Published var configs: [AIProviderID: AIProviderConfig] = [:]
    @Published var activeProviderID: AIProviderID = .gemini
    @Published var connectionStatus: [AIProviderID: ConnectionStatus] = [:]

    private init() {
        register(GeminiProvider())
        for id in AIProviderID.allCases {
            configs[id] = AppSettings.shared.loadProviderConfig(for: id) ?? .defaultConfig(for: id)
        }
    }

    private func register(_ provider: AIProvider) {
        providers[provider.id] = provider
    }

    var activeProvider: AIProvider? { providers[activeProviderID] }

    func isConfigured(_ id: AIProviderID) -> Bool {
        providers[id]?.isConfigured() ?? false
    }

    func modelBinding(for id: AIProviderID) -> String {
        configs[id]?.selectedModel ?? ""
    }

    func setModel(_ model: String, for id: AIProviderID) {
        configs[id]?.selectedModel = model
        persist(id)
    }

    func setAPIKey(_ key: String, for id: AIProviderID) throws {
        try KeychainManager.shared.saveAPIKey(key, for: id)
        objectWillChange.send()
    }

    func removeAPIKey(for id: AIProviderID) throws {
        try KeychainManager.shared.deleteAPIKey(for: id)
        connectionStatus[id] = .unknown
        objectWillChange.send()
    }

    func testConnection(for id: AIProviderID) async {
        connectionStatus[id] = .testing
        let status = await providers[id]?.testConnection() ?? .failed("Provider not registered.")
        connectionStatus[id] = status
    }

    private func persist(_ id: AIProviderID) {
        guard let config = configs[id] else { return }
        AppSettings.shared.saveProviderConfig(config, for: id)
    }
}
