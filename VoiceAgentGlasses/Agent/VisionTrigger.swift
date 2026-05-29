import Foundation

/// Decides whether a user utterance refers to something *visual*, so we know
/// whether to attach the latest glasses frame to the LLM request.
enum VisionTrigger {
    private static let keywords: Set<String> = [
        "look", "looking", "see", "seeing", "watch", "watching",
        "this", "that", "these", "those", "here", "there",
        "show", "showing", "front of me", "in front", "around me",
        "read", "reading", "color", "label", "sign", "screen", "object",
        "picture", "image", "scene", "view"
    ]

    static func shouldAttachFrame(_ utterance: String) -> Bool {
        let lower = utterance.lowercased()
        for kw in keywords where lower.contains(kw) { return true }
        return false
    }
}
