# VoiceAgentGlasses

iOS app that pairs **Meta AI glasses** (via the
[Meta Wearables Device Access Toolkit](https://github.com/facebook/meta-wearables-dat-ios))
with a voice-driven AI agent. Speak from the phone, optionally referencing what
you're looking at through the glasses, and route the conversation to any LLM:

- **Claude** (Anthropic API)
- **Ollama** running on your own machine
- Any **OpenAI-compatible** endpoint (LM Studio, vLLM, Groq, etc.)

> **Status:** Phases 1–5 implemented, ready for first compile on a Mac.
> Real DAT session wiring is intentionally stubbed (falls back to MockDeviceKit)
> pending verification against the SDK's actual entry points — see
> [Handoff notes](#handoff-notes).

---

## How it works

```
[Meta glasses] --video frames--> [iOS app] <--mic/speaker--> [user]
                                     |
                                     | HTTPS
                                     v
                            [Claude | Ollama | OpenAI-compatible]
```

1. User holds the mic button → `SFSpeechRecognizer` transcribes.
2. `VisionTrigger` decides if the utterance is visual ("look", "see", "this"…).
   If yes, the latest glasses frame is downscaled to ~768px / JPEG-encoded and
   attached to the LLM request. Otherwise text-only.
3. Selected `LLMClient` streams the reply.
4. Tokens are appended to the conversation and fed sentence-by-sentence to
   `AVSpeechSynthesizer` so playback starts before generation finishes.

---

## Layout

```
VoiceAgentGlasses/
├── VoiceAgentGlasses/
│   ├── App/
│   │   ├── VoiceAgentApp.swift       @main, owns all StateObjects
│   │   └── RootView.swift            preview + status + conversation + PTT
│   ├── Glasses/
│   │   ├── DATSessionManager.swift   real/mock session, latestFrame
│   │   └── GlassesPreviewView.swift  renders latest frame
│   ├── Voice/
│   │   ├── SpeechRecognizer.swift    SFSpeechRecognizer wrapper
│   │   └── Speaker.swift             AVSpeechSynthesizer, sentence-buffered
│   ├── LLM/
│   │   ├── LLMClient.swift           protocol + ChatMessage + LLMBackend
│   │   ├── AnthropicClient.swift     SSE streaming, vision-capable
│   │   ├── OllamaClient.swift        /api/chat NDJSON streaming
│   │   └── OpenAICompatibleClient.swift  /v1/chat/completions SSE
│   ├── Agent/
│   │   ├── VisionTrigger.swift       keyword check for "look/see/this/…"
│   │   ├── ConversationStore.swift   bounded history, system prompt
│   │   └── AgentCoordinator.swift    STT → vision → LLM → TTS pipeline
│   ├── Settings/
│   │   ├── AppSettings.swift         @AppStorage-backed config
│   │   └── SettingsView.swift        backend picker + URLs/keys
│   └── Resources/
│       └── Info.plist                permissions declared up front
└── docs/
    ├── MAC_BUILD.md                  set up Xcode project & first run
    └── OLLAMA_LAN.md                 expose Ollama on Windows to the phone
```

---

## Build

You need macOS + Xcode 15.4+. See [`docs/MAC_BUILD.md`](docs/MAC_BUILD.md) for
the exact steps. Short version:

1. Create a new Xcode **iOS App** project named `VoiceAgentGlasses` at the repo root.
2. Replace the auto-generated app files with this folder's contents.
3. **Add Package Dependencies** → `https://github.com/facebook/meta-wearables-dat-ios`,
   add both `DeviceAccessToolkit` and `MockDeviceKit` to the app target.
4. Set `INFOPLIST_FILE` to `VoiceAgentGlasses/Resources/Info.plist` (or merge the
   keys into the project-generated Info).
5. Build & run on the iPhone.

The app conditionally imports `DeviceAccessToolkit`; without it, the session
manager runs a synthetic mock-frame loop so the UI works end-to-end in
Simulator without real glasses.

---

## Configure a backend

In **Settings** (gear icon):

- **Claude** — paste an Anthropic API key. Default model: `claude-sonnet-4-6`.
- **Ollama** — follow [`docs/OLLAMA_LAN.md`](docs/OLLAMA_LAN.md), then point the
  Base URL at `http://<your-pc-ip>:11434`. Default model: `llava`.
- **OpenAI-compatible** — any base URL + (optional) key + model name.

The **Vision** section has an "always attach frame" toggle. Off by default —
frames only get sent when the user says "look", "see", "this", "show", etc.
Keeps requests cheap and private.

---

## Handoff notes

For the next team picking this up on GitHub:

### What's wired and working
- All four UI pieces: preview, status bar, conversation history, PTT button.
- Streaming for all three LLM backends (Claude, Ollama, OpenAI-compatible).
- Voice in (SFSpeechRecognizer) and out (AVSpeechSynthesizer, sentence-flush).
- Multimodal request encoding for all three backends.
- Settings persistence via `@AppStorage`.
- Error surfacing via banner.

### What needs verification / completion
1. **Real DAT session wiring.** `DATSessionManager.connectReal()` currently
   falls through to the mock loop. Once the team has SDK headers in hand, replace
   with actual:
   - device discovery
   - pairing / session setup
   - subscription to the video frame stream
   - mapping incoming frames to `UIImage` and assigning to `latestFrame`

   The rest of the app reads `latestFrame` and `state` — those are the only
   contracts to preserve.

2. **Keychain for secrets.** `AppSettings.anthropicKey` and `openaiKey` live in
   `UserDefaults` for development speed. Move to Keychain (`Security.framework`)
   before any distribution.

3. **Background audio.** TTS may pause when the app backgrounds. Add a
   background-audio mode capability in the entitlements if hands-free behavior
   is desired with the phone in a pocket.

4. **Conversation persistence.** `ConversationStore` is in-memory only. Add
   disk persistence if multi-session history is wanted.

5. **Model picker UX.** Models are free-text fields. Could be replaced with a
   dropdown populated from the backend (`/api/tags` on Ollama, `/v1/models` on
   OpenAI-compatible).

6. **Localization.** STT and TTS are hardcoded to `en-US`. Surface in Settings
   if multi-language support is needed.

### Known iOS gotchas
- iPhone will refuse to install on first run until the developer cert is
  trusted under **Settings → General → VPN & Device Management**.
- Local Network permission prompt appears the first time the app hits Ollama on
  a LAN IP. The `Info.plist` string is already in place.
- Free Apple Developer accounts re-sign every 7 days; for longer-lived installs
  you need the $99 paid program.

---

## License

TBD — coordinate with the team before publishing.
