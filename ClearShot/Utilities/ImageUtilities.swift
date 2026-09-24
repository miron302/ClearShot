import AppKit
import Vision
import UniformTypeIdentifiers

enum ClipboardManager {
    @discardableResult
    static func copy(_ image: NSImage) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }

    @discardableResult
    static func copy(text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}

enum FileSaveError: LocalizedError {
    case userCancelled
    case writeFailed
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .userCancelled: return nil
        case .writeFailed: return "The screenshot could not be saved to disk."
        case .unsupportedFormat: return "This image format isn't supported for saving."
        }
    }
}

enum ImageFileWriter {
    /// Presents the standard macOS save panel and writes the image in the
    /// user's preferred format (from Settings → General).
    @MainActor
    static func presentSavePanel(for image: NSImage, suggestedName: String) throws {
        let format = AppSettings.shared.screenshotFormat
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(suggestedName).\(format.fileExtension)"
        panel.directoryURL = AppSettings.shared.defaultSaveLocation
        panel.allowedContentTypes = [utType(for: format)]
        panel.canCreateDirectories = true

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { throw FileSaveError.userCancelled }
        try write(image, to: url, format: format)
    }

    /// Saves directly to the configured default location without prompting —
    /// used when "Default screenshot behavior" is set to save immediately.
    @MainActor static func saveToDefaultLocation(_ image: NSImage, suggestedName: String) throws -> URL {
        let format = AppSettings.shared.screenshotFormat
        let url = AppSettings.shared.defaultSaveLocation.appendingPathComponent("\(suggestedName).\(format.fileExtension)")
        try write(image, to: url, format: format)
        return url
    }

    private static func write(_ image: NSImage, to url: URL, format: ScreenshotFormat) throws {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else {
            throw FileSaveError.writeFailed
        }
        let fileType: NSBitmapImageRep.FileType
        switch format {
        case .png: fileType = .png
        case .jpeg: fileType = .jpeg
        case .tiff: fileType = .tiff
        case .heic: fileType = .png // NSBitmapImageRep has no native HEIC encoder; fall back to PNG.
        }
        guard let data = rep.representation(using: fileType, properties: [.compressionFactor: 0.92]) else {
            throw FileSaveError.writeFailed
        }
        do {
            try data.write(to: url)
        } catch {
            throw FileSaveError.writeFailed
        }
    }

    private static func utType(for format: ScreenshotFormat) -> UTType {
        switch format {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        case .heic: return .png
        }
    }
}

/// On-device OCR via the Vision framework — no AI provider required for
/// "Extract Text" / "Copy Text".
enum TextRecognizer {
    static func recognizeText(in image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AIError.imageEncodingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
