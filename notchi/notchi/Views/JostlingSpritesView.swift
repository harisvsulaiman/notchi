import SwiftUI

/// Displays up to 2 session sprites. When there are 2, they jostle and bump
/// into each other as if fighting for the user's attention.
struct JostlingSpritesView: View {
    let sessions: [SessionData]

    @State private var jostlePhase: CGFloat = 0

    private var isFighting: Bool { sessions.count >= 2 }

    var body: some View {
        ZStack {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                SessionSpriteView(
                    state: session.state,
                    isSelected: index == 0
                )
                .frame(width: 18, height: 18)
                .offset(
                    x: spriteX(index: index),
                    y: spriteY(index: index)
                )
                .zIndex(index == 0 ? 1 : 0)
            }
        }
        .frame(width: isFighting ? 30 : 18, height: 18)
        .onAppear {
            guard isFighting else { return }
            withAnimation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
            ) {
                jostlePhase = 1
            }
        }
        .onChange(of: sessions.count) { _, count in
            if count >= 2 {
                jostlePhase = 0
                withAnimation(
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                ) {
                    jostlePhase = 1
                }
            } else {
                jostlePhase = 0
            }
        }
    }

    private func spriteX(index: Int) -> CGFloat {
        guard isFighting else { return 0 }
        // Base spread: sprites sit apart
        let base: CGFloat = index == 0 ? -4 : 8
        // Bump toward each other then apart
        let bump: CGFloat = index == 0 ? 3 : -3
        return base + bump * jostlePhase
    }

    private func spriteY(index: Int) -> CGFloat {
        guard isFighting else { return 0 }
        // Alternating vertical pop — one goes up while the other goes down
        let lift: CGFloat = index == 0 ? -2 : 1
        return lift * jostlePhase
    }
}
