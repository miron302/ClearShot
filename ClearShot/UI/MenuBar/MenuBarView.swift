import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var historyStore: ScreenshotHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ClearShot")
                    .font(.system(size: 14, weight: .bold))
                Text("Fast, AI-assisted screenshots")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            VStack(spacing: 4) {
                menuRow(icon: "macwindow", title: "Full Screen", shortcut: appSettings.fullScreenShortcut) {
                    (NSApp.delegate as? AppDelegate)?.captureFullScreen()
                }
                menuRow(icon: "crop", title: "Capture Region", shortcut: appSettings.regionShortcut) {
                    (NSApp.delegate as? AppDelegate)?.captureRegion()
                }
                menuRow(icon: "macwindow.on.rectangle", title: "Capture Window", shortcut: appSettings.windowShortcut) {
                    (NSApp.delegate as? AppDelegate)?.captureWindow()
                }
            }
            .padding(.horizontal, 8)

            Divider().padding(.vertical, 8)

            HistoryView()
                .environmentObject(historyStore)

            Divider().padding(.vertical, 4)

            VStack(spacing: 2) {
                menuRow(icon: "gearshape", title: "Settings…", shortcut: nil) {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                menuRow(icon: "power", title: "Quit ClearShot", shortcut: nil) {
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .frame(width: 300)
    }

    private func menuRow(icon: String, title: String, shortcut: KeyboardShortcutSpec?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).frame(width: 18)
                Text(title).font(.system(size: 12.5))
                Spacer()
                if let shortcut {
                    Text(shortcut.displayString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowButtonStyle())
    }
}

private struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.accentColor.opacity(0.25) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
    }
}
