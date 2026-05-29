import Foundation

@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []

    private let systemPrompt: ChatMessage

    init(systemPrompt: String =
         "You are a concise voice assistant for a user wearing Meta AI glasses. " +
         "Replies are spoken aloud, so keep them short, natural, and free of markdown. " +
         "When the user references something visual ('this', 'look', 'see'), " +
         "ground your answer in the attached image when present.") {
        self.systemPrompt = ChatMessage(role: .system, text: systemPrompt)
    }

    func append(_ msg: ChatMessage) {
        messages.append(msg)
    }

    func appendUser(_ text: String, imageJPEG: Data? = nil) -> ChatMessage {
        let m = ChatMessage(role: .user, text: text, imageJPEG: imageJPEG)
        messages.append(m)
        return m
    }

    func appendAssistant(_ text: String) -> UUID {
        let m = ChatMessage(role: .assistant, text: text)
        messages.append(m)
        return m.id
    }

    func appendAssistantDelta(id: UUID, delta: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].text.append(delta)
    }

    /// History payload sent to the LLM: system + last N turns, images stripped
    /// from previous turns to keep request size bounded.
    func payload(maxTurns: Int = 8) -> [ChatMessage] {
        let recent = messages.suffix(maxTurns * 2)
        var trimmed: [ChatMessage] = []
        for (i, m) in recent.enumerated() {
            var copy = m
            if i < recent.count - 1 { copy.imageJPEG = nil }
            trimmed.append(copy)
        }
        return [systemPrompt] + trimmed
    }

    func clear() {
        messages.removeAll()
    }
}
