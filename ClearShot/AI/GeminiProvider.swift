import AppKit

/// Talks to the Gemini API directly over `URLSession` — no SDK dependency,
/// per the "avoid unnecessary dependencies" requirement.
///
/// Model names are user-selectable in Settings because Google revises its
/// model lineup fairly often; `availableModels` lists sensible defaults as of
/// this writing, but the picker also accepts a custom model string.
final class GeminiProvider: AIProvider {
    let id: AIProviderID = .gemini

    static let defaultAnalysisModel = "gemini-2.5-flash"
    static let defaultImageModel = "gemini-2.5-flash-image"

    let availableModels = [
        "gemini-2.5-flash",
        "gemini-2.5-pro",
        "gemini-2.5-flash-image",
        "gemini-1.5-flash",
    ]

    var supportsImageEditing: Bool { true }

    private let session: URLSession = .shared
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    func isConfigured() -> Bool {
        (try? KeychainManager.shared.readAPIKey(for: .gemini)) != nil
    }

    func testConnection() async -> ConnectionStatus {
        guard let key = try? KeychainManager.shared.readAPIKey(for: .gemini), !key.isEmpty else {
            return .failed(AIError.missingAPIKey.localizedDescription)
        }
        do {
            _ = try await performTextOnlyPing(apiKey: key)
            return .connected
        } catch let error as AIError {
            return .failed(error.localizedDescription)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func analyze(_ request: AIAnalysisRequest, model: String) async throws -> String {
        let apiKey = try requireAPIKey()
        guard let imageData = request.image.pngRepresentation else { throw AIError.imageEncodingFailed }

        let url = try endpoint(model: model, apiKey: apiKey)
        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": request.prompt],
                    ["inline_data": ["mime_type": "image/png", "data": imageData.base64EncodedString()]]
                ]
            ]]
        ]

        let data = try await postJSON(url: url, body: body)
        return try Self.extractText(from: data)
    }

    func edit(_ request: AIEditRequest, model: String) async throws -> NSImage {
        let apiKey = try requireAPIKey()
        guard let imageData = request.image.pngRepresentation else { throw AIError.imageEncodingFailed }

        let url = try endpoint(model: model, apiKey: apiKey)
        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": request.instruction],
                    ["inline_data": ["mime_type": "image/png", "data": imageData.base64EncodedString()]]
                ]
            ]],
            "generationConfig": ["responseModalities": ["IMAGE", "TEXT"]]
        ]

        let data = try await postJSON(url: url, body: body)
        return try Self.extractImage(from: data)
    }

    // MARK: - Networking helpers

    private func requireAPIKey() throws -> String {
        guard let key = try? KeychainManager.shared.readAPIKey(for: .gemini), !key.isEmpty else {
            throw AIError.missingAPIKey
        }
        return key
    }

    private func endpoint(model: String, apiKey: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)") else {
            throw AIError.invalidResponse("Malformed request URL.")
        }
        return url
    }

    private func performTextOnlyPing(apiKey: String) async throws -> Data {
        let url = try endpoint(model: Self.defaultAnalysisModel, apiKey: apiKey)
        let body: [String: Any] = ["contents": [["parts": [["text": "ping"]]]]]
        return try await postJSON(url: url, body: body)
    }

    private func postJSON(url: URL, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIError.network(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIError.invalidResponse("No HTTP response.")
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 400, 401, 403:
            throw AIError.invalidAPIKey
        case 429:
            throw AIError.rateLimited
        case 500...599:
            throw AIError.providerUnavailable
        default:
            throw AIError.invalidResponse("HTTP \(http.statusCode)")
        }
    }

    // MARK: - Response parsing

    private static func extractText(from data: Data) throws -> String {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw AIError.invalidResponse("Missing candidates/content in response.")
        }

        let text = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
        guard !text.isEmpty else { throw AIError.invalidResponse("No text content returned.") }
        return text
    }

    private static func extractImage(from data: Data) throws -> NSImage {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw AIError.invalidResponse("Missing candidates/content in response.")
        }

        for part in parts {
            if let inline = part["inline_data"] as? [String: Any] ?? part["inlineData"] as? [String: Any],
               let base64 = inline["data"] as? String,
               let imageData = Data(base64Encoded: base64),
               let image = NSImage(data: imageData) {
                return image
            }
        }
        throw AIError.invalidResponse("No image data returned by the model.")
    }
}

extension NSImage {
    var pngRepresentation: Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
