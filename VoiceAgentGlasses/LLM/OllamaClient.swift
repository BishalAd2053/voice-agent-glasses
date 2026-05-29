import Foundation

/// Streams from Ollama's /api/chat endpoint.
/// Docs: https://github.com/ollama/ollama/blob/main/docs/api.md
struct OllamaClient: LLMClient {
    let baseURL: URL
    let model: String

    init(baseURL: URL, model: String = "llava") {
        self.baseURL = baseURL
        self.model = model
    }

    func stream(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var req = URLRequest(url: baseURL.appendingPathComponent("/api/chat"))
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "content-type")

                    let msgs: [[String: Any]] = messages.map { m in
                        var entry: [String: Any] = [
                            "role": m.role.rawValue,
                            "content": m.text
                        ]
                        if let img = m.imageJPEG {
                            entry["images"] = [img.base64EncodedString()]
                        }
                        return entry
                    }
                    let body: [String: Any] = [
                        "model": model,
                        "messages": msgs,
                        "stream": true
                    ]
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        var data = Data()
                        for try await b in bytes { data.append(b) }
                        throw LLMError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
                    }

                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }

                        if let msg = obj["message"] as? [String: Any],
                           let content = msg["content"] as? String,
                           !content.isEmpty {
                            continuation.yield(content)
                        }
                        if let done = obj["done"] as? Bool, done { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
