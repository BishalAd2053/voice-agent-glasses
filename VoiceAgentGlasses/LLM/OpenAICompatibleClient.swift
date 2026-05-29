import Foundation

/// Streams from any OpenAI Chat Completions-compatible endpoint (LM Studio, vLLM, Groq, etc.).
struct OpenAICompatibleClient: LLMClient {
    let baseURL: URL
    let apiKey: String
    let model: String

    init(baseURL: URL, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }

    func stream(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var req = URLRequest(url: baseURL.appendingPathComponent("/v1/chat/completions"))
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "content-type")
                    if !apiKey.isEmpty {
                        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    }

                    let msgs: [[String: Any]] = messages.map { m in
                        if let img = m.imageJPEG {
                            let dataURL = "data:image/jpeg;base64,\(img.base64EncodedString())"
                            return [
                                "role": m.role.rawValue,
                                "content": [
                                    ["type": "text", "text": m.text],
                                    ["type": "image_url", "image_url": ["url": dataURL]]
                                ] as [Any]
                            ]
                        } else {
                            return ["role": m.role.rawValue, "content": m.text]
                        }
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
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = obj["choices"] as? [[String: Any]],
                              let first = choices.first,
                              let delta = first["delta"] as? [String: Any],
                              let content = delta["content"] as? String,
                              !content.isEmpty
                        else { continue }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
