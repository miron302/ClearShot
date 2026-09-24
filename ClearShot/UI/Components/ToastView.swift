import AppKit
import SwiftUI

/// A borderless, auto-dismissing banner window anchored to the top of the
/// main screen. Used exclusively by `ErrorPresenter` so error handling stays
/// decoupled from whatever window happens to be focused.
@MainActor
final class ToastWindowController {
    static let shared = ToastWindowController()
    private var window: NSWindow?
    private var dismissWorkItem: DispatchWorkItem?

    func showError(_ error: ErrorPresenter.PresentedError) {
        dismissWorkItem?.cancel()
        window?.close()

        let view = ToastBanner(title: error.title, detail: error.detail) { [weak self] in
            self?.dismiss()
        }
        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = true
        panel.setContentSize(NSSize(width: 360, height: error.detail == nil ? 64 : 88))

        if let screen = NSScreen.main {
            let x = screen.frame.midX - 180
            let y = screen.frame.maxY - 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            panel.animator().alphaValue = 1
        }

        window = panel

        let workItem = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func dismiss() {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            window.animator().alphaValue = 0
        } completionHandler: {
            window.close()
        }
        self.window = nil
    }
}

private struct ToastBanner: View {
    let title: String
    let detail: String?
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12.5, weight: .semibold))
                if let detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
        .offset(y: appeared ? 0 : -12)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { appeared = true } }
    }
}
