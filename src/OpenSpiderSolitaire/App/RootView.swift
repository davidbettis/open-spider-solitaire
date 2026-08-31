import SwiftUI

/// Type-safe navigation routes (retained for later app-shell screens).
enum Route: Hashable {
    case game
    case highScores
    case settings
}

/// Root: shows the menu until a game is started, then the full-screen board.
/// The active `GameSession` is created here and injected into the environment
/// (spec: `GameBoardView` reads `@Environment(GameSession.self)`).
struct RootView: View {
    @State private var game: GameSession?

    init() {
        #if DEBUG
        // Debug/QA hook: `AUTOSTART_MODE=1|2|4` launches straight into a game
        // (used for screenshots / future UI tests). No effect without the var.
        if let raw = ProcessInfo.processInfo.environment["AUTOSTART_MODE"],
           let value = Int(raw), let mode = SuitMode(rawValue: value) {
            var rng = SystemRandomNumberGenerator()
            _game = State(initialValue: GameSession(mode: mode, rng: &rng))
        }
        #endif
    }

    var body: some View {
        if let game {
            GameBoardView(onExit: { self.game = nil })
                .environment(game)
        } else {
            MenuView(onStart: startGame)
        }
    }

    private func startGame(_ mode: SuitMode) {
        var rng = SystemRandomNumberGenerator()
        game = GameSession(mode: mode, rng: &rng)
    }
}

#Preview {
    RootView()
}
