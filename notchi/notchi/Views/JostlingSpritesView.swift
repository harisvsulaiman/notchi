import SwiftUI

/// Displays up to 2 session sprites side by side. When there are 2, they
/// take turns stepping forward as if fighting for the user's attention.
struct JostlingSpritesView: View {
    let sessions: [SessionData]

    /// 0 = left sprite forward, 1 = right sprite forward
    @State private var phase: CGFloat = 0

    private var isFighting: Bool { sessions.count >= 2 }

    var body: some View {
        HStack(spacing: 4) {
            if sessions.isEmpty {
                SessionSpriteView(state: .idle, isSelected: true)
                    .frame(width: 18, height: 18)
            } else if sessions.count == 1 {
                SessionSpriteView(state: sessions[0].state, isSelected: true)
                    .frame(width: 18, height: 18)
            } else {
                // Left sprite: steps forward (up) when phase = 0
                SessionSpriteView(state: sessions[0].state, isSelected: true)
                    .frame(width: 18, height: 18)
                    .offset(y: -3 * (1 - phase))

                // Right sprite: steps forward (up) when phase = 1
                SessionSpriteView(state: sessions[1].state, isSelected: true)
                    .frame(width: 18, height: 18)
                    .offset(y: -3 * phase)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard isFighting else { return }
            startFighting()
        }
        .onChange(of: sessions.count) { _, count in
            if count >= 2 {
                startFighting()
            } else {
                phase = 0
            }
        }
    }

    private func startFighting() {
        phase = 0
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            phase = 1
        }
    }
}
