import SwiftUI

/// Minimal win summary. The full cascade + records screen live in
/// `animations.md` / `high-scores.md`; this is the functional placeholder.
struct WinOverlay: View {
    let session: GameSession
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("You Win!").font(.largeTitle.bold())
                Text("Score \(session.displayScore)  ·  \(session.elapsed.clockString)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("New Game") {
                        var rng = SystemRandomNumberGenerator()
                        session.newGame(mode: session.state.mode, rng: &rng)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Menu", action: onExit)
                        .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(40)
        }
    }
}
