import Foundation

/// Stable identifier for a provider. Using a string-backed enum (rather than
/// a raw string) keeps the provider list exhaustive-switchable while still
/// being easy to extend — add a case here, add a matching `AIProvider`
/// implementation, and register it in `AIProviderManager`.
enum AIProviderID: String, Codable, CaseIterable, Identifiable {
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        }
    }

    var iconSystemName: String {
        switch self {
        case .gemini: return "sparkles"
        }
    }
}

/// Non-secret configuration for a provider. The API key itself never lives
/// here — it's stored exclusively in the Keychain via `KeychainManager`.
struct AIProviderConfig: Codable, Equatable {
    var providerID: AIProviderID
    var selectedModel: String
    var isEnabled: Bool

    static func defaultConfig(for id: AIProviderID) -> AIProviderConfig {
        switch id {
        case .gemini:
            return AIProviderConfig(providerID: .gemini, selectedModel: GeminiProvider.defaultAnalysisModel, isEnabled: true)
        }
    }
}

enum ConnectionStatus: Equatable {
    case unknown
    case testing
    case connected
    case failed(String)
}
