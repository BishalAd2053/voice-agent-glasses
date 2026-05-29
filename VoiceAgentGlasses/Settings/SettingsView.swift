import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Backend") {
                    Picker("LLM", selection: $settings.backendRaw) {
                        ForEach(LLMBackend.allCases) { b in
                            Text(b.displayName).tag(b.rawValue)
                        }
                    }
                }

                switch settings.backend {
                case .anthropic:
                    Section("Anthropic") {
                        SecureField("API key", text: $settings.anthropicKey)
                        TextField("Model", text: $settings.anthropicModel)
                    }
                case .ollama:
                    Section("Ollama (your machine)") {
                        TextField("Base URL", text: $settings.ollamaURL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        TextField("Model", text: $settings.ollamaModel)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Text("Tip: on your Windows box run `set OLLAMA_HOST=0.0.0.0 && ollama serve`, then put http://<machine-ip>:11434 above.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .openAICompatible:
                    Section("OpenAI-compatible") {
                        TextField("Base URL", text: $settings.openaiURL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        SecureField("API key (optional)", text: $settings.openaiKey)
                        TextField("Model", text: $settings.openaiModel)
                    }
                }

                Section("Vision") {
                    Toggle("Always attach glasses frame", isOn: $settings.alwaysAttachFrame)
                    Text("Off: only attach when you mention 'look', 'see', 'this', etc.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView().environmentObject(AppSettings())
}
