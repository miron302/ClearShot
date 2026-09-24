import SwiftUI

struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section("What stays on your Mac") {
                privacyRow(icon: "internaldrive", text: "Screenshots you capture, including history, are stored only in your local Application Support folder.")
                privacyRow(icon: "key", text: "AI provider API keys are stored exclusively in the macOS Keychain and never leave your device except in direct, encrypted requests to that provider.")
                privacyRow(icon: "text.viewfinder", text: "OCR / text extraction runs fully on-device using Apple's Vision framework — no network request is made.")
            }

            Section("What's sent to an AI provider") {
                privacyRow(icon: "sparkles", text: "A screenshot is sent to your configured AI provider only when you explicitly choose “Ask AI” or “Edit with AI.”")
                privacyRow(icon: "arrow.up.right", text: "That request also includes the prompt or instruction you typed. Nothing is sent automatically or in the background.")
                privacyRow(icon: "doc.text.magnifyingglass", text: "Review your provider's own privacy policy — ClearShot has no control over how a third-party AI provider retains or processes data you send it.")
            }

            Section {
                Text("ClearShot itself collects no analytics, telemetry, or usage data of any kind.")
                    .font(.system(size: 11.5, weight: .medium))
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    private func privacyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}
