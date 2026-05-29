import SwiftUI

@main
@MainActor
struct VoiceAgentApp: App {
    @StateObject private var session: DATSessionManager
    @StateObject private var settings: AppSettings
    @StateObject private var speech: SpeechRecognizer
    @StateObject private var agent: AgentCoordinator

    @MainActor
    init() {
        let session = DATSessionManager()
        let settings = AppSettings()
        let speech = SpeechRecognizer()
        let agent = AgentCoordinator(
            conversation: ConversationStore(),
            speaker: Speaker(),
            settings: settings,
            session: session)
        _session = StateObject(wrappedValue: session)
        _settings = StateObject(wrappedValue: settings)
        _speech = StateObject(wrappedValue: speech)
        _agent = StateObject(wrappedValue: agent)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(settings)
                .environmentObject(speech)
                .environmentObject(agent)
                .environmentObject(agent.conversation)
                .environmentObject(agent.speaker)
                .task {
                    await session.start()
                    _ = await speech.requestAuthorization()
                }
        }
    }
}
