import SwiftUI

struct GlobalSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var openRouterKey = ""
    @State private var keyStatus = "Not inspected"

    var body: some View {
        Form {
            Section("Inference Provider") {
                Picker("Provider", selection: $environment.provider) {
                    ForEach(ProviderChoice.allCases) { Text($0.rawValue).tag($0) }
                }
                TextField("Documented context window (tokens)", text: $environment.contextWindowTokens)
                TextField("Maximum output tokens", text: $environment.maximumOutputTokens)
                LabeledContent("Readiness", value: environment.providerReadiness.rawValue.capitalized)
                Text("Connected means transport worked. Only a recorded live capability and quality walkthrough can mark a model qualified.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Ollama - on this Mac") {
                TextField("Loopback URL", text: $environment.ollamaURL)
                TextField("Installed local model", text: $environment.ollamaModel)
                Text("Only loopback IP addresses and ports are accepted. ProjectOS does not install, start, stop, or download Ollama models.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("OpenRouter - external and billed separately") {
                TextField("Stable model ID", text: $environment.openRouterModel)
                TextField("Pinned upstream provider route", text: $environment.openRouterRoute)
                TextField("Approved test spending ceiling (USD)", text: $environment.approvedSpendingCeilingUSD)
                SecureField("API key (saved to Keychain)", text: $openRouterKey)
                HStack {
                    Text(keyStatus).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Remove Key", role: .destructive) {
                        environment.removeOpenRouterKey()
                        openRouterKey = ""
                        keyStatus = "Removed from Keychain"
                    }
                    Button("Save Key") {
                        Task { keyStatus = await environment.saveOpenRouterKey(openRouterKey) ? "Saved in Keychain" : "Could not save key" }
                    }
                }
                Text("No automatic retry, model fallback, or hidden provider switch. Usage and cost are shown only when returned by the provider.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Test Connectivity") { environment.testProvider() }
                Spacer()
                Button("Save Settings") { environment.saveProviderSettings() }.buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Provider Settings")
    }
}
