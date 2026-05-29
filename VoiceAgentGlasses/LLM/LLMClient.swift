import Foundation
import UIKit

enum ChatRole: String, Codable { case system, user, assistant }

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: ChatRole
    var text: String
    /// JPEG-encoded image bytes for multimodal turns. Not persisted.
    var imageJPEG: Data?

    init(id: UUID = UUID(), role: ChatRole, text: String, imageJPEG: Data? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.imageJPEG = imageJPEG
    }

    private enum CodingKeys: String, CodingKey { case id, role, text }
}

protocol LLMClient {
    /// Streamed reply. Yields text deltas; finishes when the model is done.
    func stream(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error>
}

enum LLMBackend: String, CaseIterable, Identifiable, Codable {
    case anthropic
    case ollama
    case openAICompatible

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .anthropic: "Claude (Anthropic)"
        case .ollama: "Ollama (self-hosted)"
        case .openAICompatible: "OpenAI-compatible"
        }
    }
}

enum LLMError: LocalizedError {
    case missingConfig(String)
    case http(Int, String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingConfig(let m): "Missing config: \(m)"
        case .http(let code, let body): "HTTP \(code): \(body)"
        case .decoding(let m): "Decode error: \(m)"
        }
    }
}
