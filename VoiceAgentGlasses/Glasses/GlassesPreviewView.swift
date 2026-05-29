import SwiftUI

struct GlassesPreviewView: View {
    @EnvironmentObject var session: DATSessionManager

    var body: some View {
        ZStack {
            if let frame = session.latestFrame {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for first frame…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    GlassesPreviewView()
        .environmentObject(DATSessionManager())
        .background(.black)
}
