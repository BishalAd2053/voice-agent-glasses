import Foundation

/// Streams from the Anthropic Messages API using SSE.
/// Docs: https://docs.anthropic.com/en/api/messages-streaming
struct AnthropicClient: LLMClient {
    let apiKey: String
    let model: String
    let baseURL: URL

    init(apiKey: String,
         model: String = "claude-sonnet-4-6",
         baseURL: URL = URL(string: "https://api.anthropic.com")!) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
    }

    func stream(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard !apiKey.isEmpty else {
                        throw LLMError.missingConfig("ANTHROPIC_API_KEY")
                    }

                    var req = URLRequest(url: baseURL.appendingPathComponent("/v1/messages"))
                    req.httpMethod = "POST"
                    req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    req.setValue("application/json", forHTTPHeaderField: "content-type")

                    let body = try Self.encodeBody(model: model, messages: messages)
                    req.httpBody = body

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        var data = Data()
                        for try await b in bytes { data.append(b) }
                        throw LLMError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8) else { continue }
                        if let delta = Self.extractDelta(data) {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Encoding

    private static func encodeBody(model: String, messages: [ChatMessage]) throws -> Data {
        var system: String? = nil
        var msgs: [[String: Any]] = []

        for m in messages {
            switch m.role {
            case .system:
                system = (system.map { $0 + "\n" } ?? "") + m.text
            case .user, .assistant:
                var content: [[String: Any]] = []
                if let img = m.imageJPEG {
                    content.append([
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": img.base64EncodedString()
                        ]
                    ])
                }
                if !m.text.isEmpty {
                    content.append(["type": "text", "text": m.text])
                }
                msgs.append(["role": m.role.rawValue, "content": content])
            }
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "stream": true,
            "messages": msgs
        ]
        if let system { body["system"] = system }
        return try JSONSerialization.data(withJSONObject: body)
    }

    private static func extractDelta(_ data: Data) -> String? {
        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = obj["type"] as? String,
            type == "content_block_delta",
            let delta = obj["delta"] as? [String: Any],
            let text = delta["text"] as? String
        else { return nil }
        return text
    }
}
