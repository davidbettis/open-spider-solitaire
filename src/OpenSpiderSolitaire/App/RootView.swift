import SwiftUI

/// Type-safe navigation routes (retained for later app-shell screens).
///
/// High Scores carries an optional row to open on and call out: the title
/// screen pushes it empty, a win pushes the row it just earned.
enum Route: Hashable {
    case game
    case highScores(HighScoreHighlight?)
    case settings
}

/// Root: shows the menu until a game is started, then the full-screen board.
/// The active `GameSession` is created here and injected into the environment
/// (spec: `GameBoardView` reads `@Environment(GameSession.self)`).
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var game: GameSession?
    @State private var highScores: HighScoresStore
    @State private var settings: SettingsStore
    @State private var path: [Route] = []

    private let persistence: PersistenceService

    init() {
        let persistence = PersistenceService()
        self.persistence = persistence
        _highScores = State(initialValue: HighScoresStore(
            storage: PersistedHighScoresStorage(persistence: persistence)))
        _settings = State(initialValue: SettingsStore(
            storage: PersistedSettingsStorage(persistence: persistence)))

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
                GameBoardView(persistence: persistence, onExit: leaveGame)
                    .environment(game)
            } else {
                NavigationStack(path: $path) {
                    MenuView(onStart: startGame,
                             onSettings: { path.append(.settings) },
                             onHighScores: { path.append(.highScores(nil)) })
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .highScores(let highlight): HighScoresView(highlight: highlight)
                            case .settings: SettingsView()
                            case .game: EmptyView()
                            }
                        }
                }
            }
        }
        .environment(highScores)
        .environment(settings)
        // Applied at the root so it covers the board, the menu, and everything
        // pushed on top of them. `nil` for .system means "do not override".
        .preferredColorScheme(settings.appearance.colorScheme)
        // Derived once, here, so every bar and screen below agrees on how much
        // room it is playing with — and so it follows the *window*, which on
        // iPad changes with multitasking, not the device it is installed on.
        .environment(\.chrome, Chrome(horizontal: horizontalSizeClass,
                                      vertical: verticalSizeClass))
    }

    /// Leave the board. A win that made the leaderboard hands back its row, and
    /// lands on High Scores showing it — the title screen would otherwise be the
    /// last thing between the player and a result they just earned. The stack is
    /// set before the board goes away, so the screen is already there rather
    /// than sliding in over the menu.
    private func leaveGame(showing highlight: HighScoreHighlight?) {
        path = highlight.map { [Route.highScores($0)] } ?? []
        game = nil
    }

    /// Difficulty comes from Settings, not from the caller: the title screen no
    /// longer asks, so the stored preference is the only source.
    private func startGame() {
        var rng = SystemRandomNumberGenerator()
        game = GameSession(mode: settings.suitMode, rng: &rng)
    }
}

#Preview {
    RootView()
}
