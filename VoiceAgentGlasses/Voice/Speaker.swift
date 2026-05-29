import Foundation
import AVFoundation

@MainActor
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking: Bool = false

    private let synth = AVSpeechSynthesizer()
    private var buffer: String = ""
    private var flushTimer: Timer?

    override init() {
        super.init()
        synth.delegate = self
    }

    // Streamed token input: tokens append to a buffer that gets flushed at sentence
    // boundaries so speech sounds natural instead of word-by-word.
    func feed(_ token: String) {
        buffer.append(token)
        if let range = buffer.rangeOfCharacter(from: .init(charactersIn: ".!?\n")) {
            let upTo = buffer.index(after: range.lowerBound)
            let sentence = String(buffer[..<upTo]).trimmingCharacters(in: .whitespacesAndNewlines)
            buffer = String(buffer[upTo...])
            if !sentence.isEmpty { speakChunk(sentence) }
        }
    }

    func flush() {
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""
        if !trimmed.isEmpty { speakChunk(trimmed) }
    }

    func stop() {
        buffer = ""
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    private func speakChunk(_ text: String) {
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: "en-US")
        utt.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(utt)
        isSpeaking = true
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utt: AVSpeechUtterance) {
        Task { @MainActor in
            if !s.isSpeaking { self.isSpeaking = false }
        }
    }
}
