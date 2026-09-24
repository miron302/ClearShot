import AppKit
import SwiftUI
import QuartzCore

/// Owns the floating panel that appears after every capture. Kept as a
/// standalone controller (rather than a SwiftUI `Window` scene) so we get
/// full control over positioning, level, and the spring-in/fade-out
/// animation on close.
final class ScreenshotResultWindowController: NSObject {
    private var panel: NSPanel?
    private let screenshot: CapturedScreenshot

    init(screenshot: CapturedScreenshot) {
        self.screenshot = screenshot
    }

    @MainActor
    func showAnimated() {
        let content = ScreenshotResultView(screenshot: screenshot, isEmbedded: false) { [weak self] in
            self?.closeAnimated()
        }
        .environmentObject(AIProviderManager.shared)
        .environmentObject(AppSettings.shared)

        let hosting = NSHostingController(rootView: content)
        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.titled, .closable, .fullSizeContentView, .nonactivatingPanel]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false

        let width: CGFloat = 460
        let height: CGFloat = 520
        panel.setContentSize(NSSize(width: width, height: height))

        if let screen = NSScreen.main {
            let x = screen.frame.maxX - width - 40
            let y = screen.frame.maxY - height - 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        let startFrame = panel.frame
        panel.setFrame(startFrame.insetBy(dx: 12, dy: -12).offsetBy(dx: 0, dy: 12), display: false)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(startFrame, display: true)
        }

        self.panel = panel
    }

    @MainActor
    func closeAnimated() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.close()
        }
    }
}
