import Testing
@testable import OpenSpiderSolitaire

@Suite struct ScoringTests {

    @Test func startingScoreIs500() {
        let state = makeState(board: emptyBoard())
        #expect(Scoring.internalScore(for: state) == 500)
        #expect(Scoring.displayScore(for: state) == 500)
    }

    @Test func derivedFormula() {
        var state = makeState(board: emptyBoard())
        state.moveCount = 12
        state.undoCount = 3
        state.board.completedRuns = [CompletedRun(cardIDs: [], suit: .spades),
                                     CompletedRun(cardIDs: [], suit: .hearts)]
        // 500 - 12 - 3 + 200 = 685
        #expect(Scoring.internalScore(for: state) == 685)
    }

    @Test func displayScoreFloorsAtZero() {
        var state = makeState(board: emptyBoard())
        state.moveCount = 512   // 500 - 512 = -12 internally
        #expect(Scoring.internalScore(for: state) == -12)
        #expect(Scoring.displayScore(for: state) == 0)
    }

    /// The spec §8 worked example: clear (+100), undo, re-clear nets a single
    /// +100 while every move and undo is charged.
    @Test func clearUndoReclearNetsSinglePlus100() {
        func score(moves: Int, undos: Int, runs: Int) -> Int {
            var s = makeState(board: emptyBoard())
            s.moveCount = moves
            s.undoCount = undos
            s.board.completedRuns = (0..<runs).map { _ in CompletedRun(cardIDs: [], suit: .spades) }
            return Scoring.internalScore(for: s)
        }
        #expect(score(moves: 0, undos: 0, runs: 0) == 500)   // start
        #expect(score(moves: 1, undos: 0, runs: 1) == 599)   // move clears a run
        #expect(score(moves: 1, undos: 1, runs: 0) == 498)   // undo the clear
        #expect(score(moves: 2, undos: 1, runs: 1) == 597)   // re-clear
    }
}
