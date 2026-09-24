import SwiftUI
import AppKit

struct ShortcutsSettingsView: View {
    @EnvironmentObject private var appSettings: AppSettings

    var body: some View {
        Form {
            Section {
                Text("Click a shortcut field, then press a new key combination. At least one modifier key (⌘ ⇧ ⌥ ⌃) is required.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Section("Shortcuts") {
                shortcutRow(title: "Activate Screenshot Interface", spec: $appSettings.activationShortcut)
                shortcutRow(title: "Full-Screen Screenshot", spec: $appSettings.fullScreenShortcut)
                shortcutRow(title: "Region Screenshot", spec: $appSettings.regionShortcut)
                shortcutRow(title: "Window Screenshot", spec: $appSettings.windowShortcut)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    private func shortcutRow(title: String, spec: Binding<KeyboardShortcutSpec>) -> some View {
        HStack {
            Text(title)
            Spacer()
            ShortcutRecorderView(shortcut: spec) {
                (NSApp.delegate as? AppDelegate)?.configureHotKeys()
            }
        }
    }
}
