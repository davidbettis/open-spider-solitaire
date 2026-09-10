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

    // MARK: The column strip's tap target

    @Test func strippedTapPlaysTheTopCard() {
        // The strip taps `count - 1`, so it plays the column's top card and
        // only that card — the same move tapping the card itself makes.
        let s = session()
        #expect(s.tap(column: 0, index: s.state.board.tableau[0].count - 1))
        #expect(s.state.board.tableau[0].map(\.rank) == [.four])       // 6♠ left
        #expect(s.state.board.tableau[1].map(\.rank) == [.seven, .six])
    }

    @Test func strippedTapOnAnEmptyColumnIsInert() {
        // An empty column asks for index -1. That must be a silent no-op rather
        // than a crash or a move, since the whole strip is now tappable.
        let s = session()
        let before = s.state.board
        #expect(!s.tap(column: 9, index: -1))                          // col 9 is empty
        #expect(s.state.board == before)
        #expect(s.state.moveCount == 0)
    }

    @Test func strippedTapWithAFaceDownTopIsInert() {
        var board = emptyBoard()
        board.tableau[0] = [makeCard(0, .six, .spades, up: false)]
        board.tableau[1] = [makeCard(1, .seven, .hearts)]
        let s = GameSession(resuming: makeState(board: board), clock: FakeClock())
        let before = s.state.board
        #expect(!s.tap(column: 0, index: 0))
        #expect(s.state.board == before)
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

    // MARK: Blocked-deal flash (spec §6.3)

    /// 9 columns holding a card, column 3 empty, one deal still in stock.
    private func boardWithEmptyColumns(_ empties: Set<Int>) -> Board {
        var board = emptyBoard()
        for i in 0..<10 where !empties.contains(i) {
            board.tableau[i] = [makeCard(i, .seven, .spades)]
        }
        board.stock = makeRun(.spades, from: 13, to: 4, startID: 100)   // 10 cards
        return board
    }

    @Test func flashMarksEveryEmptyColumn() {
        let interaction = BoardInteraction()
        interaction.flashEmptyColumns(board: boardWithEmptyColumns([3, 7]))
        #expect(interaction.blockedColumns == [3, 7])
    }

    @Test func flashIsANoOpWhenNoColumnIsEmpty() {
        let interaction = BoardInteraction()
        interaction.flashEmptyColumns(board: boardWithEmptyColumns([]))
        #expect(interaction.blockedColumns.isEmpty)
    }

    @Test func clearingTheFlashRemovesTheMarks() {
        let interaction = BoardInteraction()
        interaction.flashEmptyColumns(board: boardWithEmptyColumns([3]))
        interaction.clearFlash()
        #expect(interaction.blockedColumns.isEmpty)
    }

    /// The deck stays live while cards remain, so a refused deal is what
    /// triggers the flash — the control is never silently dead.
    @Test func refusedDealIsWhatFlashes() {
        let board = boardWithEmptyColumns([3])
        let s = GameSession(resuming: makeState(board: board), clock: FakeClock())
        #expect(s.state.board.dealsRemaining == 1)   // deck shows "1", not greyed
        #expect(!s.canDeal)                          // but the engine refuses

        let interaction = BoardInteraction()
        if !s.deal() { interaction.flashEmptyColumns(board: s.state.board) }
        #expect(interaction.blockedColumns == [3])
    }

    @Test func successfulDealDoesNotFlash() {
        let board = boardWithEmptyColumns([])
        let s = GameSession(resuming: makeState(board: board), clock: FakeClock())
        let interaction = BoardInteraction()
        if !s.deal() { interaction.flashEmptyColumns(board: s.state.board) }
        #expect(interaction.blockedColumns.isEmpty)
        #expect(s.state.board.dealsRemaining == 0)
    }
}
