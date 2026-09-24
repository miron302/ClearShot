import AppKit

/// A single request to analyze a screenshot in some way.
struct AIAnalysisRequest {
    let image: NSImage
    let prompt: String
}

/// A single request to transform a screenshot into a new image.
struct AIEditRequest {
    let image: NSImage
    let instruction: String
}

enum AIError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case network(underlying: Error)
    case invalidResponse(String)
    case providerUnavailable
    case imageEncodingFailed
    case editingNotSupported

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key is configured for this provider."
        case .invalidAPIKey:
            return "The API key was rejected. Double-check it in Settings → Providers."
        case .rateLimited:
            return "The AI provider is rate-limiting requests. Please wait a moment and try again."
        case .network:
            return "A network error occurred while contacting the AI provider."
        case .invalidResponse(let detail):
            return "The AI provider returned an unexpected response. \(detail)"
        case .providerUnavailable:
            return "The AI provider is currently unavailable."
        case .imageEncodingFailed:
            return "The screenshot could not be prepared for upload."
        case .editingNotSupported:
            return "This provider doesn't support image editing yet."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey, .invalidAPIKey:
            return "Open Settings → Providers to add or update your API key."
        case .rateLimited:
            return "Try again in a minute, or check your provider's usage dashboard."
        case .network:
            return "Check your internet connection and try again."
        default:
            return nil
        }
    }
}

/// The contract every AI provider must satisfy. Screenshot analysis and
/// image editing are separate capabilities because not every provider (or
/// model) will support both — providers advertise support via
/// `supportsImageEditing`.
protocol AIProvider: AnyObject {
    var id: AIProviderID { get }
    var availableModels: [String] { get }

    func isConfigured() -> Bool
    func testConnection() async -> ConnectionStatus
    var supportsImageEditing: Bool { get }

    func analyze(_ request: AIAnalysisRequest, model: String) async throws -> String
    func edit(_ request: AIEditRequest, model: String) async throws -> NSImage
}
