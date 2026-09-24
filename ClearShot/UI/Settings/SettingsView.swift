import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var providerManager: AIProviderManager
    @EnvironmentObject private var historyStore: ScreenshotHistoryStore

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            ProvidersSettingsView()
                .tabItem { Label("Providers", systemImage: "sparkles") }

            AppearanceSettingsView()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            PrivacySettingsView()
                .tabItem { Label("Privacy", systemImage: "hand.raised") }

            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .appAppearance(appSettings.appearance)
        .animation(.easeInOut(duration: 0.15), value: appSettings.appearance)
    }
}
