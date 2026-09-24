import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var historyStore: ScreenshotHistoryStore
    @State private var showingRetentionChangedToast = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch ClearShot at login", isOn: $appSettings.launchAtLogin)
                Toggle("Show menu bar icon", isOn: $appSettings.showMenuBarIcon)
            }

            Section("Saving") {
                Picker("Screenshot format", selection: $appSettings.screenshotFormat) {
                    ForEach(ScreenshotFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                Picker("Default behavior", selection: $appSettings.defaultSaveBehavior) {
                    ForEach(DefaultSaveBehavior.allCases) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                HStack {
                    Text("Default save location")
                    Spacer()
                    Text(appSettings.defaultSaveLocation.lastPathComponent)
                        .foregroundStyle(.secondary)
                    Button("Choose…") { chooseSaveLocation() }
                }
            }

            Section("History") {
                Picker("Keep history", selection: $appSettings.historyRetention) {
                    ForEach(HistoryRetention.allCases, id: \.self) { policy in
                        Text(policy.label).tag(policy)
                    }
                }
                HStack {
                    Text("\(historyStore.items.count) screenshot\(historyStore.items.count == 1 ? "" : "s") stored")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                    Spacer()
                    Button("Clear History", role: .destructive) {
                        withAnimation { historyStore.clearAll() }
                    }
                    .disabled(historyStore.items.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    private func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = appSettings.defaultSaveLocation
        if panel.runModal() == .OK, let url = panel.url {
            appSettings.defaultSaveLocation = url
        }
    }
}

extension HistoryRetention: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .off: hasher.combine(0)
        case .lastN(let n): hasher.combine(1); hasher.combine(n)
        case .days(let d): hasher.combine(2); hasher.combine(d)
        case .unlimited: hasher.combine(3)
        }
    }
}
