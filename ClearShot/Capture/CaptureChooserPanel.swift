import AppKit
import SwiftUI

/// A compact, borderless "quick action" bar that appears near the top of the
/// screen when the activation shortcut fires — similar in spirit to macOS's
/// own screenshot toolbar, but themed for ClearShot.
enum CaptureChooserPanel {
    private static var panel: NSPanel?

    @MainActor
    static func show(onFullScreen: @escaping () -> Void, onRegion: @escaping () -> Void, onWindow: @escaping () -> Void) {
        panel?.close()

        let content = ChooserBar(
            onFullScreen: { dismiss(); onFullScreen() },
            onRegion: { dismiss(); onRegion() },
            onWindow: { dismiss(); onWindow() },
            onCancel: { dismiss() }
        )
        let hosting = NSHostingController(rootView: content)
        let newPanel = NSPanel(contentViewController: hosting)
        newPanel.styleMask = [.borderless, .nonactivatingPanel]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.level = .screenSaver
        newPanel.hasShadow = true
        newPanel.setContentSize(NSSize(width: 300, height: 76))

        if let screen = NSScreen.main {
            let x = screen.frame.midX - 150
            let y = screen.frame.maxY - 140
            newPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        newPanel.alphaValue = 0
        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            newPanel.animator().alphaValue = 1
        }

        panel = newPanel
    }

    private static func dismiss() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.close()
        }
        self.panel = nil
    }
}

private struct ChooserBar: View {
    let onFullScreen: () -> Void
    let onRegion: () -> Void
    let onWindow: () -> Void
    let onCancel: () -> Void
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 10) {
            chooserButton(icon: "macwindow", label: "Full Screen", action: onFullScreen)
            chooserButton(icon: "crop", label: "Region", action: onRegion)
            chooserButton(icon: "macwindow.on.rectangle", label: "Window", action: onWindow)
            Divider().frame(height: 28)
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { appeared = true }
        }
    }

    private func chooserButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(width: 74, height: 52)
        }
        .buttonStyle(ChooserButtonStyle())
    }
}

private struct ChooserButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .background(configuration.isPressed ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
