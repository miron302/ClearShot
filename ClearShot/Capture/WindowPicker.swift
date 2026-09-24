import AppKit
import SwiftUI

struct PickableWindow: Identifiable {
    let id: CGWindowID
    let title: String
    let appName: String
    let thumbnail: NSImage
}

/// Presents a small floating grid of currently-visible windows and captures
/// whichever one the user clicks.
enum WindowPicker {

    @MainActor
    static func presentAndCapture() async throws -> CapturedScreenshot? {
        guard ScreenCaptureService.shared.hasPermission() else { throw CaptureError.permissionDenied }

        let windows = collectWindows()
        guard !windows.isEmpty else { return nil }

        return await withCheckedContinuation { continuation in
            let controller = WindowPickerPanelController(windows: windows) { picked in
                guard let picked else {
                    continuation.resume(returning: nil)
                    return
                }
                Task {
                    let shot = try? await ScreenCaptureService.shared.captureWindow(windowID: picked.id, appName: picked.appName)
                    continuation.resume(returning: shot)
                }
            }
            controller.show()
        }
    }

    private static func collectWindows() -> [PickableWindow] {
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var results: [PickableWindow] = []
        for info in infoList {
            guard
                let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                let appName = info[kCGWindowOwnerName as String] as? String,
                appName != "ClearShot"
            else { continue }

            let title = (info[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? appName

            guard let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming]) else {
                continue
            }
            let thumb = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
            results.append(PickableWindow(id: windowID, title: title, appName: appName, thumbnail: thumb))
        }
        return results
    }
}

private final class WindowPickerPanelController: NSObject {
    private var panel: NSPanel?
    private let windows: [PickableWindow]
    private let completion: (PickableWindow?) -> Void

    init(windows: [PickableWindow], completion: @escaping (PickableWindow?) -> Void) {
        self.windows = windows
        self.completion = completion
    }

    @MainActor
    func show() {
        let content = WindowPickerGrid(windows: windows) { [weak self] picked in
            self?.panel?.close()
            self?.completion(picked)
        }
        let hosting = NSHostingController(rootView: content)
        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.titled, .closable, .nonactivatingPanel, .fullSizeContentView]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.level = .floating
        panel.setContentSize(NSSize(width: 620, height: 440))
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }
}

private struct WindowPickerGrid: View {
    let windows: [PickableWindow]
    let onPick: (PickableWindow?) -> Void
    @State private var hovered: CGWindowID?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select a Window")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Cancel") { onPick(nil) }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(windows) { window in
                        VStack(spacing: 8) {
                            Image(nsImage: window.thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 90)
                                .frame(maxWidth: .infinity)
                                .background(Color.black.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(hovered == window.id ? Color.accentColor : .clear, lineWidth: 2)
                                )
                            Text(window.title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Text(window.appName)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(8)
                        .scaleEffect(hovered == window.id ? 1.04 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovered)
                        .onHover { isHovering in hovered = isHovering ? window.id : nil }
                        .onTapGesture { onPick(window) }
                    }
                }
                .padding(16)
            }
        }
        .background(.regularMaterial)
    }
}
