import Foundation
import SwiftUI
import Combine
import UIKit

#if canImport(DeviceAccessToolkit)
import DeviceAccessToolkit
#endif

#if canImport(MockDeviceKit)
import MockDeviceKit
#endif

enum SessionState: Equatable {
    case idle
    case connecting
    case connected
    case streaming
    case disconnected
    case error(String)

    var label: String {
        switch self {
        case .idle: "Idle"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .streaming: "Streaming"
        case .disconnected: "Disconnected"
        case .error(let m): "Error: \(m)"
        }
    }

    var color: Color {
        switch self {
        case .idle, .disconnected: .gray
        case .connecting: .yellow
        case .connected: .blue
        case .streaming: .green
        case .error: .red
        }
    }
}

@MainActor
final class DATSessionManager: ObservableObject {
    @Published private(set) var state: SessionState = .idle
    @Published private(set) var latestFrame: UIImage?
    @Published private(set) var isUsingMock: Bool = false

    private var streamTask: Task<Void, Never>?

    func start() async {
        state = .connecting

        #if canImport(DeviceAccessToolkit)
        isUsingMock = false
        await connectReal()
        #else
        isUsingMock = true
        await connectMock()
        #endif
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        state = .disconnected
    }

    // MARK: - Real DAT path

    #if canImport(DeviceAccessToolkit)
    private func connectReal() async {
        // TODO Phase 1+: wire to actual DAT discovery + session APIs.
        // Real API surface needs to be confirmed against the SDK headers;
        // we stub this in mock mode for now even on-device.
        isUsingMock = true
        await connectMock()
    }
    #endif

    // MARK: - Mock path (works without hardware / without the SDK)

    private func connectMock() async {
        try? await Task.sleep(for: .milliseconds(400))
        state = .connected
        try? await Task.sleep(for: .milliseconds(200))
        state = .streaming
        startMockFrameLoop()
    }

    private func startMockFrameLoop() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                let img = MockFrameGenerator.frame(tick: tick)
                await MainActor.run { self?.latestFrame = img }
                tick += 1
                try? await Task.sleep(for: .milliseconds(66)) // ~15 fps
            }
        }
    }
}

// Generates a simple synthetic frame so the preview shows something
// before we have real glasses or the real SDK wired in.
enum MockFrameGenerator {
    static func frame(tick: Int) -> UIImage {
        let size = CGSize(width: 640, height: 360)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let hue = CGFloat((tick % 240)) / 240.0
            let bg = UIColor(hue: hue, saturation: 0.25, brightness: 0.15, alpha: 1)
            cg.setFillColor(bg.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            for i in 0..<6 {
                let x = CGFloat((tick * (i + 1)) % Int(size.width))
                let y = CGFloat(60 + i * 40)
                let r = CGRect(x: x, y: y, width: 60, height: 24)
                cg.setFillColor(UIColor(hue: CGFloat(i) / 6, saturation: 0.8, brightness: 0.9, alpha: 1).cgColor)
                cg.fill(r)
            }

            let label = "MOCK FRAME \(tick)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            label.draw(at: CGPoint(x: 16, y: 16), withAttributes: attrs)
        }
    }
}
