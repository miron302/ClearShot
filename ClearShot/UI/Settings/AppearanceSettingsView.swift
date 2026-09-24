import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var appSettings: AppSettings

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $appSettings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Motion") {
                Toggle("Enable animations", isOn: $appSettings.animationsEnabled)
                Text("Turns off entrance/exit animations for the capture overlay, result window, and buttons throughout ClearShot.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }
}
