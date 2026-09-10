import SwiftUI

/// The live game screen: HUD, the 10-column tableau (with the drag overlay), and
/// the controls, bound to the engine's ``GameSession`` (spec §4). Owns only
/// ephemeral UI state — the drag/frames coordinator and the new-game dialog.
struct GameBoardView: View {
    @Environment(GameSession.self) private var session
    @Environment(HighScoresStore.self) private var highScores
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.chrome) private var chrome

    /// Matches each card by `Card.id` as it moves between columns (spec §5.1).
    @Namespace private var cardNamespace
    @State private var interaction = BoardInteraction()
    @State private var hints = HintController()
    @State private var confirmingNewGame = false
    @State private var confirmingRestart = false
    /// Cached because `session.canAutoComplete` runs a full greedy solve; it is
    /// refreshed on board changes rather than on every view update.
    @State private var canFinish = false
    /// Recorded once per win, and cleared when a fresh game begins.
    @State private var winSummary: WinSummary?
    /// Cards the most recent deal delivered, held just long enough to stagger
    /// their arrival, then cleared so ordinary moves animate normally.
    @State private var justDealt: Set<Int> = []
    /// The run currently sweeping out of the tableau, if any.
    @State private var clearing: ClearingRun?
    @State private var clearToken = 0
    /// While set, the opening layout has not been dealt yet: the tableau
    /// renders empty and these cards wait at the deck, so they have somewhere
    /// to fly *from* (spec §5, initial deal).
    @State private var dealingIn: [Card]?

    let persistence: PersistenceService
    /// Leave the board. The win screen passes the leaderboard row this game
    /// earned so the player lands on it; the HUD's mid-game exit passes `nil`.
    let onExit: (HighScoreHighlight?) -> Void

    var body: some View {
        boardStack
            .environment(interaction)
            .background(feltBackground)
            .overlay { hintCancelCatcher }
            .overlay { winLayer }
            .modifier(BoardDialogs(confirmingNewGame: $confirmingNewGame,
                                   confirmingRestart: $confirmingRestart,
                                   onNewGame: startNewGame,
                                   onRestart: restartDeal))
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    session.resume()
                } else {
                    // Pause first so `elapsed` is settled, then write straight
                    // away rather than racing termination (spec §6.1).
                    session.pause()
                    if session.state.timerStarted && !session.isWon {
                        persistence.saveGameSynchronously(session.snapshot)
                    }
                }
            }
            // A move / deal / undo makes the hint candidates stale (spec §4.2).
            .onChange(of: session.state.board) { old, new in
                hints.invalidate()
                refreshCanFinish()
                autosave()
                react(to: BoardDiff(from: old, to: new), previous: old)
            }
            .onAppear { refreshCanFinish() }
            // Runs on appear and again whenever a new deal is drawn.
            .task(id: session.state.initialBoard) { await dealIn() }
            // A game counts as started on its first forward move, which is
            // exactly when the engine starts the clock (high-scores §6).
            .onChange(of: session.state.timerStarted) { _, started in
                if started { highScores.recordGameStarted(mode: session.state.mode) }
            }
            // Recording on the transition gives one record per win, and clears
            // the summary when a new game resets `isWon`.
            .onChange(of: session.isWon) { _, won in
                guard won else { winSummary = nil; return }
                winSummary = highScores.recordWin(mode: session.state.mode,
                                                  score: session.displayScore,
                                                  time: session.elapsed)
                // The game it described is over (spec §6.1).
                Task { await persistence.deleteGame() }
            }
    }

    private var boardStack: some View {
        VStack(spacing: 0) {
            HUDBar(session: session, nextDeal: cardsAtDeck,
                   cardNamespace: cardNamespace, onExit: { onExit(nil) }, onDeal: deal)
            tableauArea
            ControlBar(session: session,
                       confirmingNewGame: $confirmingNewGame,
                       confirmingRestart: $confirmingRestart,
                       onHint: { hints.start(board: session.state.board) })
        }
    }

    /// Any tap anywhere cancels the hint cycle (spec §4.2), so this sits above
    /// the board and the bars and swallows the gesture that cancels it.
    @ViewBuilder
    private var hintCancelCatcher: some View {
        if hints.isCycling {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { hints.cancel() }
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var winLayer: some View {
        if session.isWon {
            ZStack {
                // Scrim first, then the cascade over it, then the summary — so
                // the cards stay bright and the summary stays readable.
                Color.black.opacity(0.5)
                WinCascadeLayer(completedRuns: session.state.board.completedRuns,
                                cardSize: cascadeCardSize)
                WinOverlay(session: session, summary: winSummary,
                           onExit: { onExit(earnedHighlight) })
            }
            .ignoresSafeArea()
        }
    }

    /// The row this win put on the leaderboard, if it made the top N — what
    /// leaving the win screen hands back. A finish that missed the board has
    /// nothing to show, so it goes to the menu as before.
    private var earnedHighlight: HighScoreHighlight? {
        winSummary?.recordedEntry.map {
            HighScoreHighlight(mode: session.state.mode, entry: $0)
        }
    }

    /// Empty while the opening layout is still at the deck, so the cards have
    /// a real distance to travel.
    private var visibleTableau: [[Card]] {
        dealingIn == nil
            ? session.state.board.tableau
            : Array(repeating: [], count: BoardLayout.columnCount)
    }

    /// What the deck is holding: the opening layout mid-deal, else the next
    /// stock deal.
    private var cardsAtDeck: [Card] {
        dealingIn ?? Array(session.state.board.stock.suffix(10))
    }

    /// Deal the opening layout out of the deck rather than snapping it onto the
    /// table. Only for an untouched game — resuming a save should land on the
    /// board the player left, not replay its deal.
    private func dealIn() async {
        guard !session.isWon, session.state.moveCount == 0, !session.state.timerStarted else { return }
        let cards = session.state.board.tableau.flatMap { $0 }
        guard !cards.isEmpty else { return }

        dealingIn = cards
        justDealt = Set(cards.map(\.id))
        // One frame at the deck, so the flight starts from there.
        try? await Task.sleep(for: .milliseconds(60))
        guard !Task.isCancelled else { return }
        withAnimation(Motion.deal) { dealingIn = nil }

        let settle = Motion.dealStagger * Double(BoardLayout.columnCount) + 0.6
        try? await Task.sleep(for: .seconds(settle))
        justDealt = []
    }

    /// The cascade draws at roughly a tableau card's size, without needing the
    /// tableau's own layout — so it takes the chrome's scale rather than the
    /// board's, which is enough to keep it in proportion on either idiom.
    private var cascadeCardSize: CGSize {
        let width: CGFloat = 58 * chrome.scale
        return CGSize(width: width, height: width * BoardLayout.aspectRatio)
    }

    /// A new deal replaces the old game, so its snapshot goes with it
    /// (spec §6.1). The fresh board has no moves yet, so nothing is written
    /// back until the player actually plays.
    private func startNewGame() {
        Motion.instantly {
            var rng = SystemRandomNumberGenerator()
            session.newGame(mode: session.state.mode, rng: &rng)
        }
        Task { await persistence.deleteGame() }
    }

    /// Restart keeps the same deal, so the game stays resumable and autosave
    /// simply overwrites the snapshot on the next move.
    private func restartDeal() {
        Motion.instantly { session.restart() }
        Task { await persistence.deleteGame() }
    }

    /// Turn a board change into motion (spec §5): a dealt row is staggered
    /// per column, and the stagger flag is dropped once the row has landed so
    /// later moves are not delayed by it.
    private func react(to diff: BoardDiff, previous: Board) {
        if !diff.dealtCardIDs.isEmpty {
            justDealt = diff.dealtCardIDs
            let settle = Motion.dealStagger * Double(BoardLayout.columnCount) + 0.4
            Task {
                try? await Task.sleep(for: .seconds(settle))
                justDealt = []
            }
        }

        if !diff.clearedCardIDs.isEmpty, let run = clearedRun(diff, in: previous) {
            clearing = run
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                if clearing?.id == run.id { clearing = nil }
            }
        }
    }

    /// Rebuild the departing run from the board as it was, so the celebration
    /// starts from exactly where the cards lay.
    private func clearedRun(_ diff: BoardDiff, in previous: Board) -> ClearingRun? {
        for (column, cards) in previous.tableau.enumerated() {
            let leaving = cards.filter { diff.clearedCardIDs.contains($0.id) }
            if leaving.count == 13 {
                clearToken += 1
                return ClearingRun(id: clearToken, cards: leaving, column: column)
            }
        }
        return nil
    }

    /// Autosave the in-progress game, debounced inside the actor. A game with
    /// no moves yet is not worth resuming, so it is not written at all — which
    /// also keeps New Game's delete from being undone by a pending save.
    private func autosave() {
        guard session.state.timerStarted, !session.isWon else { return }
        let snapshot = session.snapshot
        Task { await persistence.scheduleGameSave(snapshot) }
    }

    /// Finish the board mechanically (spec §5.2). Starting an assist cancels a
    /// running hint (spec §6).
    private func finish() {
        hints.cancel()
        withAnimation(Motion.glide) { session.autoComplete() }
    }

    /// `canAutoComplete` is short-circuited early in the game, but once the
    /// stock empties it runs a greedy solve — too costly to re-evaluate on
    /// every view update, so it is recomputed only when the board changes.
    /// A won board trivially satisfies it, hence the `isWon` guard.
    private func refreshCanFinish() {
        let available = !session.isWon && session.canAutoComplete
        withAnimation(.easeInOut(duration: 0.25)) { canFinish = available }
    }

    /// Deal, or explain why not: the engine refuses while any column is empty,
    /// so flash the offending columns rather than leaving a live control that
    /// silently does nothing (spec §6.3).
    private func deal() {
        var dealt = false
        withAnimation(Motion.deal) { dealt = session.deal() }
        guard !dealt else { return }
        interaction.flashEmptyColumns(board: session.state.board)
    }

    private var tableauArea: some View {
        GeometryReader { proxy in
            let layout = BoardLayout(size: proxy.size,
                                     tableau: session.state.board.tableau,
                                     spread: chrome.pick(phone: .compact, pad: .roomy))
            ZStack(alignment: .top) {
                TableauView(tableau: visibleTableau,
                            layout: layout,
                            regionHeight: proxy.size.height,
                            cardNamespace: cardNamespace,
                            justDealtIDs: justDealt)
                if let candidate = hints.current {
                    HintLayer(candidate: candidate,
                              board: session.state.board,
                              layout: layout)
                }
                if let drag = interaction.drag {
                    DragLayer(drag: drag, layout: layout)
                }
                if let clearing {
                    ClearedRunLayer(run: clearing, layout: layout)
                }
                if canFinish {
                    FinishGameButton(action: finish)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The same colour the columns paint, so the gutters between them
            // read as part of one field rather than as gaps.
            .background(Palette.columnStrip)
            .coordinateSpace(.named("board"))
            .onPreferenceChange(ColumnFramesKey.self) { interaction.columnFrames = $0 }
        }
    }

    private var feltBackground: some View {
        Palette.table.ignoresSafeArea()
    }
}

/// The board's two confirmations, lifted out of `GameBoardView.body` so the
/// type-checker has a smaller expression to chew on.
private struct BoardDialogs: ViewModifier {
    @Binding var confirmingNewGame: Bool
    @Binding var confirmingRestart: Bool
    let onNewGame: () -> Void
    let onRestart: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Start a new game?", isPresented: $confirmingNewGame,
                                titleVisibility: .visible) {
                Button("New Game", role: .destructive, action: onNewGame)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This ends the game in progress and deals a new one.")
            }
            .confirmationDialog("Restart this deal?", isPresented: $confirmingRestart,
                                titleVisibility: .visible) {
                Button("Restart", role: .destructive, action: onRestart)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The same cards are dealt again from the start.")
            }
    }
}
