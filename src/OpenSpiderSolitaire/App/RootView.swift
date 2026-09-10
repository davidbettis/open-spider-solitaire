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

    /// The game in flight, whether or not it is on screen. It outlives a trip
    /// to the menu — that is what Continue continues — and is cleared only when
    /// the game is over or replaced.
    @State private var game: GameSession?
    /// Whether that game is the screen right now. `game != nil && !isPlaying`
    /// is the suspended state: a board waiting behind the title screen.
    @State private var isPlaying = false
    @State private var highScores: HighScoresStore
    @State private var settings: SettingsStore
    @State private var path: [Route] = []
    @State private var confirmingNewGame = false

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
            _isPlaying = State(initialValue: true)
        }

        #if DEBUG
        // Debug/QA hook: `AUTOSTART_MODE=1|2|4` launches straight into a game
        // (used for screenshots / future UI tests). No effect without the var.
        if let raw = ProcessInfo.processInfo.environment["AUTOSTART_MODE"],
           let value = Int(raw), let mode = SuitMode(rawValue: value) {
            var rng = SystemRandomNumberGenerator()
            _game = State(initialValue: GameSession(mode: mode, rng: &rng))
            _isPlaying = State(initialValue: true)
        }
        #endif
    }

    var body: some View {
        Group {
            if let game, isPlaying {
                GameBoardView(persistence: persistence, onExit: leaveGame)
                    .environment(game)
            } else {
                menuStack
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

    /// The title screen and everything reachable from it. Lifted out of `body`
    /// so the type-checker has a smaller expression to chew on — the same reason
    /// the board's dialogs live in their own modifier.
    private var menuStack: some View {
        NavigationStack(path: $path) {
            MenuView(onStart: confirmNewGameIfNeeded,
                     onContinue: continueAction,
                     onSettings: { path.append(.settings) },
                     onHighScores: { path.append(.highScores(nil)) })
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .highScores(let highlight): HighScoresView(highlight: highlight)
                    case .settings: SettingsView()
                    case .game: EmptyView()
                    }
                }
                // The board asks this before replacing a game in progress; the
                // title screen has to ask it too, because Start Game beside
                // Continue discards the same game (PRD: new-game confirmation).
                .confirmationDialog("Start a new game?", isPresented: $confirmingNewGame,
                                    titleVisibility: .visible) {
                    Button("New Game", role: .destructive, action: startGame)
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This ends the game in progress and deals a new one.")
                }
        }
    }

    /// Absent unless a game is actually waiting, so the title screen never
    /// offers a board to go back to that is not there.
    private var continueAction: (() -> Void)? {
        guard game != nil else { return nil }
        return continueGame
    }

    /// Leave the board. A win that made the leaderboard hands back its row, and
    /// lands on High Scores showing it — the title screen would otherwise be the
    /// last thing between the player and a result they just earned. The stack is
    /// set before the board goes away, so the screen is already there rather
    /// than sliding in over the menu.
    ///
    /// An unfinished game is **suspended, not ended**: it stays in memory for
    /// Continue and is written to disk on the way out, so quitting from the
    /// title screen resumes the same board. A won game has nothing left to
    /// continue, and its snapshot is already gone (`GameBoardView` deletes it on
    /// the win), so it is dropped.
    private func leaveGame(showing highlight: HighScoreHighlight?) {
        path = highlight.map { [Route.highScores($0)] } ?? []
        guard let game, !game.isWon else {
            self.game = nil
            isPlaying = false
            return
        }
        // Pause first so `elapsed` is settled before it is written — the menu
        // is not play time (PRD: the timer pauses while a menu is open) — then
        // save synchronously rather than leaving it to the debounced autosave.
        game.pause()
        persistence.saveGameSynchronously(game.snapshot)
        isPlaying = false
    }

    /// Back to the suspended board, clock running again from where it stopped.
    private func continueGame() {
        game?.resume()
        isPlaying = true
    }

    /// Start Game discards whatever is suspended, so it asks first — except
    /// when there is nothing to lose.
    private func confirmNewGameIfNeeded() {
        if game == nil {
            startGame()
        } else {
            confirmingNewGame = true
        }
    }

    /// Difficulty comes from Settings, not from the caller: the title screen no
    /// longer asks, so the stored preference is the only source.
    ///
    /// The old snapshot is deleted rather than left to be overwritten: the new
    /// game writes nothing until its first move, so without this a quit in
    /// between would resume the game the player just replaced.
    private func startGame() {
        var rng = SystemRandomNumberGenerator()
        game = GameSession(mode: settings.suitMode, rng: &rng)
        isPlaying = true
        Task { await persistence.deleteGame() }
    }
}

#Preview {
    RootView()
}
