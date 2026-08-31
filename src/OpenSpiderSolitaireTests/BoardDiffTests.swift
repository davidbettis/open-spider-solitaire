import Testing
@testable import OpenSpiderSolitaire

/// The old→new diff is pure, so it is tested without any SwiftUI (spec §11).
@Suite("BoardDiff")
struct BoardDiffTests {

    @Test("An unchanged board reports nothing")
    func noChange() {
        var board = emptyBoard()
        board.tableau[0] = makeRun(.spades, from: 5, to: 3)
        #expect(BoardDiff(from: board, to: board).isEmpty)
    }

    @Test("A relocated run is reported as moved, not dealt")
    func relocateIsAMove() {
        var before = emptyBoard()
        before.tableau[0] = [makeCard(1, .king, .spades), makeCard(2, .queen, .spades)]
        before.tableau[1] = [makeCard(3, .king, .hearts)]

        var after = before
        after.tableau[0] = [makeCard(1, .king, .spades)]
        after.tableau[1] = [makeCard(3, .king, .hearts), makeCard(2, .queen, .spades)]

        let diff = BoardDiff(from: before, to: after)
        #expect(diff.movedCardIDs == [2])
        #expect(diff.dealtCardIDs.isEmpty)
        #expect(diff.clearedCardIDs.isEmpty)
    }

    @Test("A newly exposed card is reported as flipped")
    func revealIsAFlip() {
        var before = emptyBoard()
        before.tableau[0] = [makeCard(1, .four, .hearts, up: false), makeCard(2, .six, .spades)]
        var after = before
        after.tableau[0] = [makeCard(1, .four, .hearts, up: true)]

        let diff = BoardDiff(from: before, to: after)
        #expect(diff.flippedCardIDs == [1])
        #expect(diff.clearedCardIDs == [2])
    }

    @Test("Cards arriving from the stock are dealt")
    func dealAddsCards() {
        var before = emptyBoard()
        for column in 0..<10 { before.tableau[column] = [makeCard(column, .seven, .spades)] }
        before.stock = makeRun(.hearts, from: 13, to: 4, startID: 100)

        var after = before
        for column in 0..<10 {
            after.tableau[column].append(makeCard(100 + column, .two, .clubs))
        }
        after.stock = []

        let diff = BoardDiff(from: before, to: after)
        #expect(diff.dealtCardIDs == Set(100..<110))
        #expect(diff.movedCardIDs.isEmpty)
    }

    @Test("A completed run is reported as cleared")
    func completedRunIsCleared() {
        var before = emptyBoard()
        before.tableau[0] = makeRun(.spades, from: 13, to: 1, startID: 0)   // 13 cards
        var after = emptyBoard()
        after.completedRuns = [CompletedRun(cardIDs: Array(0..<13), suit: .spades)]

        let diff = BoardDiff(from: before, to: after)
        #expect(diff.clearedCardIDs == Set(0..<13))
        #expect(diff.movedCardIDs.isEmpty)
        #expect(diff.dealtCardIDs.isEmpty)
    }

    @Test("A move that both clears a run and exposes a card reports each once")
    func clearAndFlipTogether() {
        var before = emptyBoard()
        // Column 0: a hidden card under a nearly-complete run; column 1 holds the Ace.
        before.tableau[0] = [makeCard(90, .nine, .hearts, up: false)]
            + makeRun(.spades, from: 13, to: 2, startID: 0)
        before.tableau[1] = [makeCard(50, .ace, .spades)]

        var after = emptyBoard()
        after.tableau[0] = [makeCard(90, .nine, .hearts, up: true)]
        after.completedRuns = [CompletedRun(cardIDs: Array(0..<12) + [50], suit: .spades)]

        let diff = BoardDiff(from: before, to: after)
        #expect(diff.clearedCardIDs == Set(0..<12).union([50]))
        #expect(diff.flippedCardIDs == [90])
        #expect(!diff.isEmpty)
    }
}
