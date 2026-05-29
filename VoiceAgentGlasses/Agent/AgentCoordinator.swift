import Foundation
import UIKit

/// Wires the pieces together: STT transcript → vision check → LLM stream → TTS.
@MainActor
final class AgentCoordinator: ObservableObject {
    @Published private(set) var isThinking: Bool = false
    @Published private(set) var lastError: String?

    let conversation: ConversationStore
    let speaker: Speaker
    private let settings: AppSettings
    private let session: DATSessionManager

    private var streamTask: Task<Void, Never>?

    init(conversation: ConversationStore,
         speaker: Speaker,
         settings: AppSettings,
         session: DATSessionManager) {
        self.conversation = conversation
        self.speaker = speaker
        self.settings = settings
        self.session = session
    }

    func handle(utterance raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let wantsVision = settings.alwaysAttachFrame || VisionTrigger.shouldAttachFrame(text)
        let frame: Data? = wantsVision ? snapshotJPEG() : nil

        _ = conversation.appendUser(text, imageJPEG: frame)
        let replyId = conversation.appendAssistant("")

        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            await self.runStream(replyId: replyId)
        }
    }

    func stop() {
        streamTask?.cancel()
        speaker.stop()
        isThinking = false
    }

    private func runStream(replyId: UUID) async {
        isThinking = true
        lastError = nil
        defer { isThinking = false }

        do {
            let client = try settings.makeClient()
            let payload = conversation.payload()
            // Drop the placeholder empty assistant from payload before sending.
            let outbound = payload.filter { !($0.role == .assistant && $0.text.isEmpty) }

            for try await delta in client.stream(messages: outbound) {
                if Task.isCancelled { break }
                conversation.appendAssistantDelta(id: replyId, delta: delta)
                speaker.feed(delta)
            }
            speaker.flush()
        } catch {
            lastError = error.localizedDescription
            conversation.appendAssistantDelta(id: replyId, delta: "[error: \(error.localizedDescription)]")
        }
    }

    private func snapshotJPEG() -> Data? {
        guard let img = session.latestFrame else { return nil }
        // Downscale to keep request size sane (long side ~768px).
        let target = CGFloat(768)
        let scale = min(1, target / max(img.size.width, img.size.height))
        let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
