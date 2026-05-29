import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: DATSessionManager
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var speech: SpeechRecognizer
    @EnvironmentObject var agent: AgentCoordinator
    @EnvironmentObject var conversation: ConversationStore
    @EnvironmentObject var speaker: Speaker

    @State private var showSettings = false
    @State private var errorBanner: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GlassesPreviewView()
                    .frame(height: 240)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .padding(.top, 8)

                StatusBar()
                    .padding(.horizontal)
                    .padding(.top, 6)

                ConversationView(messages: conversation.messages)
                    .frame(maxHeight: .infinity)

                if let err = errorBanner {
                    ErrorBanner(text: err) { errorBanner = nil }
                        .padding(.horizontal)
                }

                PTTBar(
                    isRecording: speech.isRecording,
                    transcript: speech.transcript,
                    isThinking: agent.isThinking,
                    isSpeaking: speaker.isSpeaking,
                    onPress: startRecording,
                    onRelease: stopAndSend,
                    onStop: { agent.stop() }
                )
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .navigationTitle("Voice Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        conversation.clear()
                    } label: { Image(systemName: "trash") }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(settings)
            }
            .onChange(of: agent.lastError) { _, new in
                if let new { errorBanner = new }
            }
            .onChange(of: speech.lastError) { _, new in
                if let new { errorBanner = new }
            }
        }
    }

    private func startRecording() {
        agent.stop()
        do { try speech.startRecording() }
        catch { errorBanner = error.localizedDescription }
    }

    private func stopAndSend() {
        let text = speech.stopRecording()
        guard !text.isEmpty else { return }
        agent.handle(utterance: text)
    }
}

// MARK: - Subviews

struct StatusBar: View {
    @EnvironmentObject var session: DATSessionManager
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(session.state.color).frame(width: 10, height: 10)
            Text(session.state.label).font(.caption)
            if session.isUsingMock {
                Text("MOCK").font(.caption2.weight(.bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            Spacer()
            Text(settings.backend.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ConversationView: View {
    let messages: [ChatMessage]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(messages.filter { $0.role != .system }) { m in
                        bubble(for: m).id(m.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(for m: ChatMessage) -> some View {
        let isUser = m.role == .user
        HStack {
            if isUser { Spacer(minLength: 32) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if m.imageJPEG != nil {
                    Label("with frame", systemImage: "camera.viewfinder")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(m.text.isEmpty ? "…" : m.text)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(isUser ? Color.blue.opacity(0.85) : Color.gray.opacity(0.2))
                    .foregroundStyle(isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if !isUser { Spacer(minLength: 32) }
        }
    }
}

struct PTTBar: View {
    let isRecording: Bool
    let transcript: String
    let isThinking: Bool
    let isSpeaking: Bool
    let onPress: () -> Void
    let onRelease: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if !transcript.isEmpty {
                Text(transcript)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack(spacing: 12) {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(!(isThinking || isSpeaking))

                pttButton
            }
        }
    }

    private var pttButton: some View {
        ZStack {
            Circle()
                .fill(isRecording ? Color.red : Color.accentColor)
                .frame(height: 64)
            Image(systemName: isRecording ? "waveform" : "mic.fill")
                .font(.title)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isRecording { onPress() } }
                .onEnded { _ in if isRecording { onRelease() } }
        )
        .overlay(alignment: .bottom) {
            Text(isRecording ? "Release to send" : "Hold to talk")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.bottom, 6)
        }
    }
}

struct ErrorBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text).font(.caption).lineLimit(3)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 4)
    }
}
