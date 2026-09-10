import Foundation
import Testing
@testable import OpenSpiderSolitaire

@MainActor
@Suite struct GameSessionTests {

    /// A tiny controlled board: two columns, a single legal single-card move
    /// (6♠ from col 0 onto 7♥ in col 1), everything else empty.
    private func twoColumnBoard() -> Board {
        var board = emptyBoard()
        board.tableau[0] = [makeCard(0, .four, .hearts, up: false), makeCard(1, .six, .spades)]
        board.tableau[1] = [makeCard(2, .seven, .hearts)]
        return board
    }

    @Test func newGameStartsUnwonAt500() {
        var rng = SplitMix64(seed: 1)
        let session = GameSession(mode: .four, rng: &rng,
                                  dealProvider: RandomDealProvider(), clock: FakeClock())
        #expect(!session.isWon)
        #expect(session.displayScore == 500)
        #expect(!session.canUndo)
        #expect(session.state.board.tableau.map(\.count).sorted(by: >) == [6, 6, 6, 6, 5, 5, 5, 5, 5, 5])
    }

    @Test func moveChargesOnePointAndEnablesUndo() {
        let session = GameSession(resuming: makeState(board: twoColumnBoard()), clock: FakeClock())
        #expect(session.move(from: 0, index: 1, to: 1))
        #expect(session.state.moveCount == 1)
        #expect(session.displayScore == 499)
        #expect(session.canUndo)
        #expect(session.state.board.tableau[0][0].isFaceUp)     // 4♥ flipped up
    }

    @Test func illegalMoveIsNoOp() {
        let session = GameSession(resuming: makeState(board: twoColumnBoard()), clock: FakeClock())
        let before = session.state.board
        #expect(!session.move(from: 0, index: 1, to: 0))        // same column
        #expect(session.state.board == before)
        #expect(session.state.moveCount == 0)
    }

    @Test func undoRestoresBoardAndChargesUndo() {
        let session = GameSession(resuming: makeState(board: twoColumnBoard()), clock: FakeClock())
        let start = session.state.board
        _ = session.move(from: 0, index: 1, to: 1)
        #expect(session.undo())
        #expect(session.state.board == start)                   // exact restore, incl. face-down 4♥
        #expect(session.state.undoCount == 1)
        #expect(session.state.moveCount == 1)                   // monotonic — not refunded
        #expect(session.displayScore == 498)                    // -1 move -1 undo
        #expect(!session.canUndo)                               // back to start
    }

    @Test func tapAutoMovesByPriority() {
        var board = emptyBoard()
        board.tableau[0] = [makeCard(0, .five, .spades)]
        board.tableau[1] = [makeCard(1, .six, .spades)]         // same-suit target
        let session = GameSession(resuming: makeState(board: board), clock: FakeClock())
        #expect(session.tap(column: 0, index: 0))
        #expect(session.state.board.tableau[0].isEmpty)
        #expect(session.state.board.tableau[1].map(\.rank) == [.six, .five])
    }

    @Test func dealBlockedWithEmptyColumn() {
        var board = emptyBoard()
        for i in 0..<9 { board.tableau[i] = [makeCard(i, .seven, .spades)] }
        board.stock = (0..<10).map { makeCard(100 + $0, .two, .hearts, up: false) }
        let session = GameSession(resuming: makeState(board: board), clock: FakeClock())
        #expect(!session.canDeal)
        #expect(!session.deal())
    }

    @Test func timerStartsOnFirstMoveAndAccumulates() {
        let clock = FakeClock(100)
        let session = GameSession(resuming: makeState(board: twoColumnBoard()), clock: clock)
        #expect(session.elapsed == 0)              // not started
        _ = session.move(from: 0, index: 1, to: 1) // starts timer at t=100
        clock.now = 105
        #expect(session.elapsed == 5)
        session.pause()
        clock.now = 200
        #expect(session.elapsed == 5)              // frozen while paused
        session.resume()
        clock.now = 210
        #expect(session.elapsed == 15)
    }

    @Test func completedSetsReflectsClears() {
        var board = emptyBoard()
        board.tableau[0] = makeRun(.spades, from: 13, to: 2, startID: 0)   // K..2
        board.tableau[1] = [makeCard(50, .ace, .spades)]
        board.completedRuns = (0..<3).map { _ in CompletedRun(cardIDs: [], suit: .spades) }
        let session = GameSession(resuming: makeState(mode: .one, board: board), clock: FakeClock())
        #expect(session.completedSets == 3)
        _ = session.move(from: 1, index: 0, to: 0)     // completes a 4th set
        #expect(session.completedSets == 4)
        #expect(!session.isWon)
    }

    @Test func winningFreezesTheClock() {
        // Seven runs already cleared; one move completes the eighth and wins.
        var board = emptyBoard()
        board.tableau[0] = makeRun(.spades, from: 13, to: 2, startID: 0)   // K..2 on col 0
        board.tableau[1] = [makeCard(50, .ace, .spades)]                   // the Ace to place
        board.completedRuns = (0..<7).map { _ in CompletedRun(cardIDs: [], suit: .spades) }
        let clock = FakeClock(0)
        let session = GameSession(resuming: makeState(mode: .one, board: board), clock: clock)
        #expect(session.move(from: 1, index: 0, to: 0))            // A onto 2 → clears 8th → win
        #expect(session.isWon)
        clock.now = 999
        let frozen = session.elapsed
        clock.now = 5000
        #expect(session.elapsed == frozen)                        // no longer ticking
    }

    @Test func suspendingToTheMenuFreezesTheClockAndTheSnapshot() {
        // Back to the title screen suspends rather than ends: the clock stops
        // (the menu is not play time) and the snapshot written on the way out
        // carries the frozen time, not the time the player spent deciding.
        let clock = FakeClock(0)
        let session = GameSession(resuming: makeState(board: twoColumnBoard()), clock: clock)
        _ = session.move(from: 0, index: 1, to: 1)      // starts the timer at t=0
        clock.now = 30

        session.pause()                                 // what leaving the board does
        let saved = session.snapshot
        clock.now = 300                                 // five minutes on the menu
        #expect(session.elapsed == 30)
        #expect(saved.elapsed == 30)

        session.resume()                                // Continue Game
        clock.now = 310
        #expect(session.elapsed == 40)
    }

    @Test func continuingAfterAQuitPicksUpTheSuspendedGame() throws {
        // The snapshot written on the way to the menu is the one a relaunch
        // resumes, so Continue and a cold launch land on the same board.
        let clock = FakeClock(0)
        let session = GameSession(resuming: makeState(board: twoColumnBoard()), clock: clock)
        _ = session.move(from: 0, index: 1, to: 1)
        clock.now = 45
        session.pause()

        let data = try JSONEncoder().encode(session.snapshot)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        let relaunched = GameSession(resuming: decoded, clock: FakeClock(1_000))

        #expect(relaunched.state.board == session.state.board)
        #expect(relaunched.elapsed == 45)               // resumes from the frozen time
        #expect(relaunched.state.moveCount == 1)
        #expect(relaunched.canUndo)
    }

    @Test func resumePreservesStateRoundTrip() throws {
        let session = GameSession(resuming: makeState(board: twoColumnBoard()), clock: FakeClock(0))
        _ = session.move(from: 0, index: 1, to: 1)
        let data = try JSONEncoder().encode(session.state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        let resumed = GameSession(resuming: decoded, clock: FakeClock(0))
        #expect(resumed.state.moveCount == 1)
        #expect(resumed.state.board == session.state.board)
        #expect(resumed.canUndo)
    }
}
