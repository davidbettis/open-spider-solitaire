import CoreGraphics
import Testing
@testable import OpenSpiderSolitaire

@MainActor
@Suite struct BoardInteractionTests {

    /// col 0: [4♥ down, 6♠ up]; col 1: [7♥ up]. Dragging 6♠ onto col 1 is legal.
    private func session() -> GameSession {
        var board = emptyBoard()
        board.tableau[0] = [makeCard(0, .four, .hearts, up: false), makeCard(1, .six, .spades)]
        board.tableau[1] = [makeCard(2, .seven, .hearts)]
        return GameSession(resuming: makeState(board: board), clock: FakeClock())
    }

    @Test func beginDragPicksUpAMovableRun() {
        let s = session()
        let interaction = BoardInteraction()
        interaction.beginDrag(column: 0, index: 1, at: .zero, board: s.state.board)
        #expect(interaction.drag?.sourceColumn == 0)
        #expect(interaction.drag?.cards.count == 1)
    }

    @Test func beginDragIgnoresFaceDownCard() {
        let s = session()
        let interaction = BoardInteraction()
        interaction.beginDrag(column: 0, index: 0, at: .zero, board: s.state.board)  // the face-down 4♥
        #expect(interaction.drag == nil)
    }

    @Test func dropOnColumnMovesTheRun() {
        let s = session()
        let interaction = BoardInteraction()
        // Register column frames as vertical strips.
        interaction.columnFrames = [
            0: CGRect(x: 0, y: 0, width: 40, height: 400),
            1: CGRect(x: 40, y: 0, width: 40, height: 400),
        ]
        interaction.beginDrag(column: 0, index: 1, at: CGPoint(x: 20, y: 30), board: s.state.board)
        interaction.updateDrag(to: CGPoint(x: 60, y: 30))   // over column 1
        interaction.endDrag(session: s)

        #expect(interaction.drag == nil)
        #expect(s.state.moveCount == 1)
        #expect(s.state.board.tableau[0].count == 1)               // 6♠ left
        #expect(s.state.board.tableau[0][0].isFaceUp)              // 4♥ revealed
        #expect(s.state.board.tableau[1].map(\.rank) == [.seven, .six])
    }

    @Test func dropOnSameColumnIsNoOp() {
        let s = session()
        let interaction = BoardInteraction()
        interaction.columnFrames = [0: CGRect(x: 0, y: 0, width: 40, height: 400)]
        interaction.beginDrag(column: 0, index: 1, at: CGPoint(x: 20, y: 30), board: s.state.board)
        interaction.updateDrag(to: CGPoint(x: 20, y: 200))   // still over column 0
        interaction.endDrag(session: s)
        #expect(s.state.moveCount == 0)
    }
}
