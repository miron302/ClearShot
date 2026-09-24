import Foundation
import CoreGraphics

/// How a given screenshot was produced. Kept simple and `Codable` so it can
/// be persisted as part of history metadata.
enum CaptureMode: Codable, Equatable {
    case fullScreen
    case region(CGRect)
    case window(windowID: CGWindowID, appName: String?)

    var displayName: String {
        switch self {
        case .fullScreen: return "Full Screen"
        case .region: return "Region"
        case .window(_, let appName): return appName.map { "Window – \($0)" } ?? "Window"
        }
    }

    var symbolName: String {
        switch self {
        case .fullScreen: return "macwindow"
        case .region: return "crop"
        case .window: return "macwindow.on.rectangle"
        }
    }
}
