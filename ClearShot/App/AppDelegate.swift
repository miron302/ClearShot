import AppKit
import SwiftUI

/// Central coordinator for the parts of ClearShot that don't fit neatly into
/// the SwiftUI `App` lifecycle: global hotkeys, the capture overlay, and the
/// floating screenshot-result window.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let hotKeyManager = GlobalHotKeyManager.shared
    private var resultWindowController: ScreenshotResultWindowController?
    private var regionSelectionController: RegionSelectionWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu-bar-first app, no Dock icon by default
        configureHotKeys()
        checkScreenRecordingPermissionSoftly()
    }

    // MARK: - Hotkeys

    /// Registers the shortcuts currently stored in AppSettings and re-registers
    /// whenever the user edits them in Settings > Shortcuts.
    @MainActor func configureHotKeys() {
        hotKeyManager.unregisterAll()

        hotKeyManager.register(shortcut: AppSettings.shared.activationShortcut, identifier: .activateInterface) { [weak self] in
            self?.presentCaptureChooser()
        }
        hotKeyManager.register(shortcut: AppSettings.shared.fullScreenShortcut, identifier: .fullScreen) { [weak self] in
            self?.captureFullScreen()
        }
        hotKeyManager.register(shortcut: AppSettings.shared.regionShortcut, identifier: .region) { [weak self] in
            self?.captureRegion()
        }
        hotKeyManager.register(shortcut: AppSettings.shared.windowShortcut, identifier: .window) { [weak self] in
            self?.captureWindow()
        }
    }

    // MARK: - Capture entry points

    /// The "activation" shortcut opens a tiny chooser so the user can pick
    /// full-screen / region / window without memorizing three shortcuts.
    @MainActor func presentCaptureChooser() {
        CaptureChooserPanel.show(
            onFullScreen: { [weak self] in self?.captureFullScreen() },
            onRegion: { [weak self] in self?.captureRegion() },
            onWindow: { [weak self] in self?.captureWindow() }
        )
    }

    func captureFullScreen() {
        Task { @MainActor in
            do {
                let shot = try await ScreenCaptureService.shared.captureFullScreen()
                present(shot)
            } catch {
                ErrorPresenter.shared.present(error)
            }
        }
    }

    func captureRegion() {
        regionSelectionController = RegionSelectionWindowController { [weak self] image, rect in
            guard let self, let image else { return }
            let shot = CapturedScreenshot(image: image, mode: .region(rect))
            Task { @MainActor in
                self.present(shot)
            }
        }
        regionSelectionController?.show()
    }

    func captureWindow() {
        Task { @MainActor in
            do {
                let picked = try await WindowPicker.presentAndCapture()
                if let picked {
                    present(picked)
                }
            } catch {
                ErrorPresenter.shared.present(error)
            }
        }
    }

    // MARK: - Result presentation

    @MainActor
    private func present(_ screenshot: CapturedScreenshot) {
        ScreenshotHistoryStore.shared.add(screenshot)
        resultWindowController = ScreenshotResultWindowController(screenshot: screenshot)
        resultWindowController?.showAnimated()
    }

    // MARK: - Permissions

    private func checkScreenRecordingPermissionSoftly() {
        // Non-blocking preflight so we can show a friendly primer window instead
        // of the terse system dialog with no context.
        if !CGPreflightScreenCaptureAccess() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                PermissionPrimerWindowController.showIfNeeded()
            }
        }
    }
}
