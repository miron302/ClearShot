import AppKit
import SwiftUI

/// Shows an explanatory window the first time ClearShot detects it lacks
/// Screen Recording access, rather than letting the bare system prompt (with
/// no context) be the user's first impression.
enum PermissionPrimerWindowController {
    private static var window: NSWindow?
    private static let didShowKey = "com.clearshot.mac.didShowPermissionPrimer"

    @MainActor
    static func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: didShowKey) else { return }
        guard !CGPreflightScreenCaptureAccess() else { return }
        UserDefaults.standard.set(true, forKey: didShowKey)
        present()
    }

    @MainActor
    static func present() {
        let content = PermissionPrimerView(
            onGrant: {
                CGRequestScreenCaptureAccess()
                window?.close()
            },
            onDismiss: { window?.close() }
        )
        let hosting = NSHostingController(rootView: content)
        let win = NSWindow(contentViewController: hosting)
        win.styleMask = [.titled, .closable]
        win.title = "Screen Recording Access"
        win.setContentSize(NSSize(width: 420, height: 280))
        win.center()
        win.level = .floating
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }
}

private struct PermissionPrimerView: View {
    let onGrant: () -> Void
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("ClearShot needs Screen Recording access")
                    .font(.system(size: 15, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text("macOS requires this permission before any app can capture the screen. ClearShot only captures a screenshot when you explicitly trigger one — nothing is recorded in the background.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 10) {
                Button("Not Now", action: onDismiss)
                    .buttonStyle(.bordered)
                Button("Open System Settings", action: onGrant)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appeared = true }
        }
    }
}
