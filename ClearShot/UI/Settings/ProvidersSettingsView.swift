import SwiftUI

struct ProvidersSettingsView: View {
    @EnvironmentObject private var providerManager: AIProviderManager

    var body: some View {
        Form {
            Section {
                Picker("Active provider", selection: $providerManager.activeProviderID) {
                    ForEach(AIProviderID.allCases) { id in
                        Text(id.displayName).tag(id)
                    }
                }
                Text("The active provider is used for every “Ask AI” and “Edit with AI” action.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            ForEach(AIProviderID.allCases) { id in
                ProviderSection(providerID: id)
            }

            Section {
                Text("API usage is billed by the provider according to their own pricing. ClearShot does not charge for AI features and never sees your API key beyond storing it securely in the macOS Keychain.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }
}

private struct ProviderSection: View {
    let providerID: AIProviderID
    @EnvironmentObject private var providerManager: AIProviderManager
    @State private var apiKeyField: String = ""
    @State private var isEditingKey = false

    private var status: ConnectionStatus {
        providerManager.connectionStatus[providerID] ?? .unknown
    }

    var body: some View {
        Section(providerID.displayName) {
            HStack {
                statusIndicator
                Text(statusLabel)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Test Connection") {
                    Task { await providerManager.testConnection(for: providerID) }
                }
                .disabled(!providerManager.isConfigured(providerID) || status == .testing)
            }

            if providerManager.isConfigured(providerID) && !isEditingKey {
                HStack {
                    Text("API Key")
                    Spacer()
                    Text("••••••••••••").foregroundStyle(.secondary).font(.system(size: 12, design: .monospaced))
                    Button("Update") { isEditingKey = true }
                    Button("Remove", role: .destructive) {
                        try? providerManager.removeAPIKey(for: providerID)
                    }
                }
            } else {
                HStack {
                    SecureField("Paste your \(providerID.displayName) API key", text: $apiKeyField)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        guard !apiKeyField.isEmpty else { return }
                        try? providerManager.setAPIKey(apiKeyField, for: providerID)
                        apiKeyField = ""
                        isEditingKey = false
                        Task { await providerManager.testConnection(for: providerID) }
                    }
                    .disabled(apiKeyField.isEmpty)
                }
                if providerID == .gemini {
                    Link("Get a Gemini API key from Google AI Studio ↗", destination: URL(string: "https://aistudio.google.com/apikey")!)
                        .font(.system(size: 11))
                }
            }

            if let provider = providerManager.providers[providerID] {
                Picker("Model", selection: Binding(
                    get: { providerManager.modelBinding(for: providerID) },
                    set: { providerManager.setModel($0, for: providerID) }
                )) {
                    ForEach(provider.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch status {
        case .unknown:
            Circle().fill(.gray).frame(width: 8, height: 8)
        case .testing:
            ProgressView().controlSize(.mini)
        case .connected:
            Circle().fill(.green).frame(width: 8, height: 8)
        case .failed:
            Circle().fill(.red).frame(width: 8, height: 8)
        }
    }

    private var statusLabel: String {
        switch status {
        case .unknown: return providerManager.isConfigured(providerID) ? "Not tested yet" : "Not configured"
        case .testing: return "Testing connection…"
        case .connected: return "Connected"
        case .failed(let message): return message
        }
    }
}
