import Testing
@testable import OpenSpiderSolitaire

@Suite struct RulesTests {

    // MARK: topRunLength

    @Test func topRunOfSameSuitDescendingCards() {
        let column = makeRun(.spades, from: 9, to: 5)   // 9 8 7 6 5
        #expect(Rules.topRunLength(column) == 5)
    }

    @Test func topRunStopsAtSuitOrRankBreak() {
        var column = makeRun(.spades, from: 9, to: 7)   // 9 8 7
        column.append(makeCard(99, .six, .hearts))      // 6♥ breaks suit
        #expect(Rules.topRunLength(column) == 1)
    }

    @Test func topRunStopsAtFaceDownCard() {
        var column = [makeCard(0, .nine, .spades, up: false)]
        column.append(makeCard(1, .eight, .spades, up: true))
        #expect(Rules.topRunLength(column) == 1) // 8 is a run of 1; 9 is face-down
    }

    @Test func topRunOfEmptyOrFaceDownTopIsZero() {
        #expect(Rules.topRunLength([]) == 0)
        #expect(Rules.topRunLength([makeCard(0, .king, .spades, up: false)]) == 0)
    }

    // MARK: canPlace

    @Test func canPlaceOntoEmptyAlways() {
        let run = makeRun(.spades, from: 5, to: 5)
        #expect(Rules.canPlace(run: run[...], onto: []))
    }

    @Test func canPlaceOntoOneHigherAnySuit() {
        let run = makeRun(.spades, from: 5, to: 4)      // highest = 5
        #expect(Rules.canPlace(run: run[...], onto: [makeCard(0, .six, .hearts)]))   // any suit
        #expect(!Rules.canPlace(run: run[...], onto: [makeCard(0, .seven, .spades)])) // gap
        #expect(!Rules.canPlace(run: run[...], onto: [makeCard(0, .five, .spades)]))  // same rank
    }

    @Test func cannotPlaceOntoFaceDownTop() {
        let run = makeRun(.spades, from: 5, to: 5)
        #expect(!Rules.canPlace(run: run[...], onto: [makeCard(0, .six, .spades, up: false)]))
    }

    // MARK: apply relocate

    @Test func relocateMovesRunAndFlipsSource() {
        var board = emptyBoard()
        board.tableau[0] = [makeCard(0, .three, .hearts, up: false), makeCard(1, .six, .spades)]
        board.tableau[1] = [makeCard(2, .seven, .clubs)]
        #expect(Rules.apply(.relocate(from: 0, count: 1, to: 1), to: &board))
        #expect(board.tableau[0].count == 1)
        #expect(board.tableau[0][0].isFaceUp)             // 3♥ was flipped up
        #expect(board.tableau[1].map(\.rank) == [.seven, .six])
    }

    @Test func illegalRelocateIsRejectedUnchanged() {
        var board = emptyBoard()
        board.tableau[0] = [makeCard(0, .six, .spades)]
        board.tableau[1] = [makeCard(1, .six, .clubs)]    // can't place 6 on 6
        let before = board
        #expect(!Rules.apply(.relocate(from: 0, count: 1, to: 1), to: &board))
        #expect(board == before)
    }

    // MARK: apply deal

    @Test func dealRejectedWhenAColumnIsEmpty() {
        var board = emptyBoard()
        for i in 0..<9 { board.tableau[i] = [makeCard(i, .seven, .spades)] }
        board.stock = makeRun(.spades, from: 13, to: 4)   // 10 cards
        #expect(!Rules.apply(.deal, to: &board))          // column 9 empty
    }

    @Test func dealAddsOneFaceUpCardPerColumn() {
        var board = emptyBoard()
        for i in 0..<10 { board.tableau[i] = [makeCard(i, .seven, .spades)] }
        board.stock = (0..<10).map { makeCard(100 + $0, .two, .hearts, up: false) }
        #expect(Rules.apply(.deal, to: &board))
        #expect(board.stock.isEmpty)
        #expect(board.tableau.allSatisfy { $0.count == 2 && $0.last!.isFaceUp })
    }

    // MARK: clears & flips

    @Test func completeRunClearsAndExposesFlip() {
        var board = emptyBoard()
        // A face-down card beneath a full K..A spade run.
        var column = [makeCard(50, .four, .hearts, up: false)]
        column += makeRun(.spades, from: 13, to: 1, startID: 0)   // K..A
        board.tableau[0] = column
        Rules.applyClearsAndFlips(&board)
        #expect(board.completedRuns.count == 1)
        #expect(board.completedRuns[0].suit == .spades)
        #expect(board.tableau[0].count == 1)
        #expect(board.tableau[0][0].isFaceUp)             // 4♥ revealed
    }

    @Test func mixedSuitFullSequenceDoesNotClear() {
        var board = emptyBoard()
        var run = makeRun(.spades, from: 13, to: 2, startID: 0)    // K..2 spades
        run.append(makeCard(99, .ace, .hearts))                   // A♥ breaks suit
        board.tableau[0] = run
        Rules.applyClearsAndFlips(&board)
        #expect(board.completedRuns.isEmpty)
    }

    // MARK: autoMoveDestination

    @Test func autoMovePrefersSameSuitContinuation() {
        var board = emptyBoard()
        board.tableau[0] = [makeCard(0, .five, .spades)]           // moving 5♠
        board.tableau[1] = [makeCard(1, .six, .hearts)]           // legal, other suit
        board.tableau[2] = [makeCard(2, .six, .spades)]           // legal, same suit — preferred
        board.tableau[3] = []                                     // empty
        #expect(Rules.autoMoveDestination(board: board, column: 0, index: 0) == 2)
    }

    @Test func autoMoveFallsBackToAnyLegalThenEmpty() {
        var board = emptyBoard()
        board.tableau[0] = [makeCard(0, .five, .spades)]
        board.tableau[1] = []                                     // empty
        board.tableau[2] = [makeCard(2, .six, .hearts)]          // any-legal (leftmost non-empty legal)
        #expect(Rules.autoMoveDestination(board: board, column: 0, index: 0) == 2)

        board.tableau[2] = [makeCard(2, .nine, .hearts)]         // no legal placement
        #expect(Rules.autoMoveDestination(board: board, column: 0, index: 0) == 1) // empty
    }

    @Test func autoMoveReturnsNilWhenNoDestination() {
        var board = emptyBoard()
        board.tableau[0] = [makeCard(0, .five, .spades)]
        // Every other column non-empty and non-fitting (9 accepts nothing here).
        for i in 1..<10 { board.tableau[i] = [makeCard(i, .nine, .hearts)] }
        #expect(Rules.autoMoveDestination(board: board, column: 0, index: 0) == nil)
    }
}
