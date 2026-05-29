import Foundation
import SwiftUI

/// Persisted app config. API keys go to UserDefaults here for simplicity;
/// move to Keychain before any real distribution.
@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("backend") var backendRaw: String = LLMBackend.anthropic.rawValue
    @AppStorage("anthropicKey") var anthropicKey: String = ""
    @AppStorage("anthropicModel") var anthropicModel: String = "claude-sonnet-4-6"

    @AppStorage("ollamaURL") var ollamaURL: String = "http://192.168.1.10:11434"
    @AppStorage("ollamaModel") var ollamaModel: String = "llava"

    @AppStorage("openaiURL") var openaiURL: String = "http://192.168.1.10:1234"
    @AppStorage("openaiKey") var openaiKey: String = ""
    @AppStorage("openaiModel") var openaiModel: String = "local-model"

    @AppStorage("alwaysAttachFrame") var alwaysAttachFrame: Bool = false

    var backend: LLMBackend {
        get { LLMBackend(rawValue: backendRaw) ?? .anthropic }
        set { backendRaw = newValue.rawValue }
    }

    func makeClient() throws -> LLMClient {
        switch backend {
        case .anthropic:
            guard !anthropicKey.isEmpty else { throw LLMError.missingConfig("Anthropic API key") }
            return AnthropicClient(apiKey: anthropicKey, model: anthropicModel)
        case .ollama:
            guard let url = URL(string: ollamaURL) else { throw LLMError.missingConfig("Ollama URL") }
            return OllamaClient(baseURL: url, model: ollamaModel)
        case .openAICompatible:
            guard let url = URL(string: openaiURL) else { throw LLMError.missingConfig("OpenAI URL") }
            return OpenAICompatibleClient(baseURL: url, apiKey: openaiKey, model: openaiModel)
        }
    }
}
