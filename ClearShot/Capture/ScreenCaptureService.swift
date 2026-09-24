import AppKit
import CoreGraphics

enum CaptureError: LocalizedError {
    case permissionDenied
    case noDisplaysFound
    case captureFailed
    case invalidRegion

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "ClearShot needs Screen Recording permission to take screenshots."
        case .noDisplaysFound:
            return "No displays were found to capture."
        case .captureFailed:
            return "The screenshot could not be captured. Please try again."
        case .invalidRegion:
            return "The selected region was too small to capture."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Open System Settings → Privacy & Security → Screen Recording and enable ClearShot, then relaunch the app."
        default:
            return nil
        }
    }
}

/// Wraps the capture APIs available on macOS 13+. We intentionally use the
/// classic `CGWindowListCreateImage` family rather than ScreenCaptureKit's
/// `SCScreenshotManager` because the latter's single-shot capture API only
/// arrived in macOS 14 — using it would break the stated macOS 13 baseline.
/// The tradeoff (a soft deprecation warning on newer OS versions) is
/// documented in the README.
final class ScreenCaptureService {
    static let shared = ScreenCaptureService()
    private init() {}

    func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func captureFullScreen() async throws -> CapturedScreenshot {
        guard hasPermission() else { throw CaptureError.permissionDenied }
        guard let mainDisplay = NSScreen.main else { throw CaptureError.noDisplaysFound }

        let displayID = mainDisplay.displayID
        let bounds = CGDisplayBounds(displayID)

        guard let cgImage = CGDisplayCreateImage(displayID, rect: bounds) else {
            throw CaptureError.captureFailed
        }
        let image = NSImage(cgImage: cgImage, size: bounds.size)
        return CapturedScreenshot(image: image, mode: .fullScreen)
    }

    /// `rect` is expected in the flipped, top-left-origin coordinate space
    /// used by the region-selection overlay (i.e. screen pixel coordinates).
    func captureRegion(_ rect: CGRect) async throws -> CapturedScreenshot {
        guard hasPermission() else { throw CaptureError.permissionDenied }
        guard rect.width >= 4, rect.height >= 4 else { throw CaptureError.invalidRegion }

        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            throw CaptureError.captureFailed
        }
        let image = NSImage(cgImage: cgImage, size: rect.size)
        return CapturedScreenshot(image: image, mode: .region(rect))
    }

    func captureWindow(windowID: CGWindowID, appName: String?) async throws -> CapturedScreenshot {
        guard hasPermission() else { throw CaptureError.permissionDenied }

        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            throw CaptureError.captureFailed
        }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: size)
        return CapturedScreenshot(image: image, mode: .window(windowID: windowID, appName: appName))
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? CGMainDisplayID()
    }
}
