import SwiftUI

struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 24)

            VStack(spacing: 4) {
                Text("ClearShot").font(.system(size: 18, weight: .bold))
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Link("View on GitHub ↗", destination: URL(string: "https://github.com/miron302/ClearShot")!)
                .font(.system(size: 12))

            Spacer()

            VStack(spacing: 4) {
                Text("Build by miron302, coded with swift.")
                Text("Distributed under the GPL-3.0 License.")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
    }
}
