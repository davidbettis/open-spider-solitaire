import Testing
@testable import OpenSpiderSolitaire

/// Restart replays the current deal; auto-complete finishes a mechanically
/// solvable board for free (specs: game-engine §10, hints-and-autocomplete §5).
@MainActor
@Suite("Restart and auto-complete")
struct RestartAndFinishTests {

    @Test("A fresh state records the deal it started from")
    func initialBoardIsCaptured() {
        var rng = SplitMix64(seed: 7)
        let session = GameSession(mode: .four, rng: &rng, clock: FakeClock())
        #expect(session.state.initialBoard == session.state.board)
    }

    @Test("Restart replays the same deal and clears all progress")
    func restartReplaysTheSameDeal() {
        var rng = SplitMix64(seed: 7)
        let session = GameSession(mode: .four, rng: &rng, clock: FakeClock())
        let dealt = session.state.board

        // Make any legal move so there is progress to discard.
        var moved = false
        for column in 0..<10 where !moved {
            moved = session.tap(column: column, index: session.state.board.tableau[column].count - 1)
        }
        #expect(moved)
        #expect(session.state.moveCount == 1)
        #expect(session.state.board != dealt)

        session.restart()
        #expect(session.state.board == dealt)          // same cards, same layout
        #expect(session.state.moveCount == 0)
        #expect(session.state.undoCount == 0)
        #expect(session.state.undoStack.isEmpty)
        #expect(!session.canUndo)
        #expect(session.state.elapsed == 0)
        #expect(!session.state.timerStarted)
        #expect(session.state.initialBoard == dealt)   // still restartable
    }

    @Test("Restart keeps the mode; new game draws a different deal")
    func restartIsNotNewGame() {
        var rng = SplitMix64(seed: 7)
        let session = GameSession(mode: .two, rng: &rng, clock: FakeClock())
        let dealt = session.state.board

        session.restart()
        #expect(session.state.mode == .two)
        #expect(session.state.board == dealt)

        var rng2 = SplitMix64(seed: 99)
        session.newGame(mode: .two, rng: &rng2)
        #expect(session.state.board != dealt)
        #expect(session.state.initialBoard == session.state.board)
    }

    // MARK: Auto-complete gating

    /// Eight face-up King→Ace runs, one per column, stock empty: trivially
    /// finishable — in fact already clearing itself.
    private func nearlyFinishedBoard() -> Board {
        var board = emptyBoard()
        for column in 0..<8 {
            board.tableau[column] = makeRun(.spades, from: 13, to: 1, startID: column * 13)
        }
        return board
    }

    @Test("Auto-complete is offered on a solvable board and finishes it free")
    func autoCompleteFinishesAtNoCost() {
        var board = emptyBoard()
        // Split one run across two columns so a real move is needed.
        board.tableau[0] = makeRun(.spades, from: 13, to: 2, startID: 0)
        board.tableau[1] = [makeCard(12, .ace, .spades)]
        for column in 2..<9 {
            board.tableau[column] = makeRun(.spades, from: 13, to: 1, startID: column * 13)
        }
        let session = GameSession(resuming: makeState(board: board), clock: FakeClock())
        let scoreBefore = session.displayScore

        #expect(session.canAutoComplete)
        session.autoComplete()
        #expect(session.isWon)
        #expect(session.state.moveCount == 0)          // points-neutral
        #expect(session.state.undoCount == 0)
        #expect(session.displayScore >= scoreBefore)   // no penalty charged
    }

    @Test("Auto-complete is not offered while stock remains")
    func notOfferedWithStockLeft() {
        var board = nearlyFinishedBoard()
        board.stock = makeRun(.hearts, from: 13, to: 4, startID: 500)   // 10 cards
        let session = GameSession(resuming: makeState(board: board), clock: FakeClock())
        #expect(!session.canAutoComplete)
    }

    @Test("Auto-complete is not offered while a card is face-down")
    func notOfferedWithHiddenCards() {
        var board = nearlyFinishedBoard()
        board.tableau[9] = [makeCard(900, .seven, .hearts, up: false)]
        let session = GameSession(resuming: makeState(board: board), clock: FakeClock())
        #expect(!session.canAutoComplete)
    }

    @Test("A won board satisfies canAutoComplete, so the UI guards on isWon")
    func wonBoardNeedsTheIsWonGuard() {
        var board = emptyBoard()
        board.completedRuns = (0..<8).map {
            CompletedRun(cardIDs: Array(($0 * 13)..<(($0 + 1) * 13)), suit: .spades)
        }
        let session = GameSession(resuming: makeState(board: board), clock: FakeClock())
        #expect(session.isWon)
        #expect(session.canAutoComplete)               // vacuously true — nothing to do
        #expect(!(!session.isWon && session.canAutoComplete))   // what the UI shows
    }
}
