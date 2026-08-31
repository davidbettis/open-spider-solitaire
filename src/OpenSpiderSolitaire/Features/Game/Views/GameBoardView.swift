import SwiftUI

/// The live game screen: HUD, the 10-column tableau (with the drag overlay), and
/// the controls, bound to the engine's ``GameSession`` (spec §4). Owns only
/// ephemeral UI state — the drag/frames coordinator and the new-game dialog.
struct GameBoardView: View {
    @Environment(GameSession.self) private var session
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

    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HUDBar(session: session, onExit: onExit, onDeal: deal)
            tableauArea
            ControlBar(session: session,
                       confirmingNewGame: $confirmingNewGame,
                       confirmingRestart: $confirmingRestart,
                       onHint: { hints.start(board: session.state.board) })
        }
        .environment(interaction)
        .background(feltBackground)
        // Any tap anywhere cancels the cycle (spec §4.2), so this sits above
        // the board and the bars and swallows the gesture that cancels it.
        .overlay {
            if hints.isCycling {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { hints.cancel() }
                    .ignoresSafeArea()
            }
        }
        .overlay {
            if session.isWon { WinOverlay(session: session, onExit: onExit) }
        }
        .confirmationDialog("Start a new game?", isPresented: $confirmingNewGame, titleVisibility: .visible) {
            Button("New Game", role: .destructive) {
                // A whole new board arrives, rather than travelling there.
                Motion.instantly {
                    var rng = SystemRandomNumberGenerator()
                    session.newGame(mode: session.state.mode, rng: &rng)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This ends the game in progress and deals a new one.")
        }
        .confirmationDialog("Restart this deal?", isPresented: $confirmingRestart, titleVisibility: .visible) {
            Button("Restart", role: .destructive) { Motion.instantly { session.restart() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The same cards are dealt again from the start.")
        }
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? session.resume() : session.pause()
        }
        // A move / deal / undo makes the candidates stale (spec §4.2).
        .onChange(of: session.state.board) { _, _ in
            hints.invalidate()
            refreshCanFinish()
        }
        .onAppear { refreshCanFinish() }
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
