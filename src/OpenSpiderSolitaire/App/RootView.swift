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
    @State private var highScores: HighScoresStore
    @State private var path: [Route] = []

    private let persistence: PersistenceService

    init() {
        let persistence = PersistenceService()
        self.persistence = persistence
        _highScores = State(initialValue: HighScoresStore(
            storage: PersistedHighScoresStorage(persistence: persistence)))

        // Resume before the first frame, so the menu never flashes over a game
        // that is still there (persistence spec §6.3).
        if let resumed = persistence.loadGameNow() {
            _game = State(initialValue: GameSession(resuming: resumed))
        }

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
        Group {
            if let game {
                GameBoardView(persistence: persistence, onExit: { self.game = nil })
                    .environment(game)
            } else {
                NavigationStack(path: $path) {
                    MenuView(onStart: startGame,
                             onHighScores: { path.append(.highScores) })
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .highScores: HighScoresView()
                            case .game, .settings: EmptyView()
                            }
                        }
                }
            }
        }
        .environment(highScores)
    }

    private func startGame(_ mode: SuitMode) {
        var rng = SystemRandomNumberGenerator()
        game = GameSession(mode: mode, rng: &rng)
    }
}

#Preview {
    RootView()
}
