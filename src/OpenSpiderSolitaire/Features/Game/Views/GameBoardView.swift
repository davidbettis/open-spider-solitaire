import SwiftUI

/// The live game screen: HUD, the 10-column tableau (with the drag overlay), and
/// the controls, bound to the engine's ``GameSession`` (spec §4). Owns only
/// ephemeral UI state — the drag/frames coordinator and the new-game dialog.
struct GameBoardView: View {
    @Environment(GameSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    @State private var interaction = BoardInteraction()
    @State private var confirmingNewGame = false

    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HUDBar(session: session, onExit: onExit)
            tableauArea
            ControlBar(session: session, confirmingNewGame: $confirmingNewGame)
        }
        .environment(interaction)
        .background(feltBackground)
        .overlay {
            if session.isWon { WinOverlay(session: session, onExit: onExit) }
        }
        .confirmationDialog("Start a new game?", isPresented: $confirmingNewGame, titleVisibility: .visible) {
            Button("New Game", role: .destructive) {
                var rng = SystemRandomNumberGenerator()
                session.newGame(mode: session.state.mode, rng: &rng)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This ends the game in progress.")
        }
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? session.resume() : session.pause()
        }
    }

    private var tableauArea: some View {
        GeometryReader { proxy in
            let layout = BoardLayout(size: proxy.size, tableau: session.state.board.tableau)
            ZStack(alignment: .top) {
                TableauView(tableau: session.state.board.tableau,
                            layout: layout,
                            regionHeight: proxy.size.height)
                if let drag = interaction.drag {
                    DragLayer(drag: drag, layout: layout)
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
