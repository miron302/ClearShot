import SwiftUI

@main
struct ClearShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var providerManager = AIProviderManager.shared
    @StateObject private var historyStore = ScreenshotHistoryStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appSettings)
                .environmentObject(providerManager)
                .environmentObject(historyStore)
        } label: {
            Image(systemName: "camera.viewfinder")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appSettings)
                .environmentObject(providerManager)
                .environmentObject(historyStore)
                .frame(width: 620, height: 460)
        }
    }
}
