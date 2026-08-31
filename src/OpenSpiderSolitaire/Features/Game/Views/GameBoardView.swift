import SwiftUI

/// The live game screen: HUD, the 10-column tableau (with the drag overlay), and
/// the controls, bound to the engine's ``GameSession`` (spec §4). Owns only
/// ephemeral UI state — the drag/frames coordinator and the new-game dialog.
struct GameBoardView: View {
    @Environment(GameSession.self) private var session
    @Environment(HighScoresStore.self) private var highScores
    @Environment(\.scenePhase) private var scenePhase

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

    let persistence: PersistenceService
    let onExit: () -> Void

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
            .onChange(of: session.state.board) { _, _ in
                hints.invalidate()
                refreshCanFinish()
                autosave()
            }
            .onAppear { refreshCanFinish() }
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
            HUDBar(session: session, onExit: onExit, onDeal: deal)
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
            WinOverlay(session: session, summary: winSummary, onExit: onExit)
        }
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
        withAnimation(Motion.glide) { dealt = session.deal() }
        guard !dealt else { return }
        interaction.flashEmptyColumns(board: session.state.board)
    }

    private var tableauArea: some View {
        GeometryReader { proxy in
            let layout = BoardLayout(size: proxy.size, tableau: session.state.board.tableau)
            ZStack(alignment: .top) {
                TableauView(tableau: session.state.board.tableau,
                            layout: layout,
                            regionHeight: proxy.size.height,
                            cardNamespace: cardNamespace)
                if let candidate = hints.current {
                    HintLayer(candidate: candidate,
                              board: session.state.board,
                              layout: layout)
                }
                if let drag = interaction.drag {
                    DragLayer(drag: drag, layout: layout)
                }
                if canFinish {
                    FinishGameButton(action: finish)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .coordinateSpace(.named("board"))
            .onPreferenceChange(ColumnFramesKey.self) { interaction.columnFrames = $0 }
        }
    }

    private var feltBackground: some View {
        LinearGradient(colors: [Color(red: 0.06, green: 0.36, blue: 0.18),
                                Color(red: 0.03, green: 0.24, blue: 0.12)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
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
