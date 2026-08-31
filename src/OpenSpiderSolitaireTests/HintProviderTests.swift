import Testing
@testable import OpenSpiderSolitaire

/// `HintProvider` is pure enumeration — no ranking, no mutation (spec §4.1).
@Suite("HintProvider")
struct HintProviderTests {

    /// A board whose columns are the given tops; every unlisted column gets a
    /// lone face-up 2♣, which accepts nothing but an Ace and so stays quiet.
    private func board(_ columns: [Int: [Card]]) -> Board {
        var tableau: [[Card]] = (0..<10).map { index in
            columns[index] ?? [makeCard(900 + index, .two, .clubs)]
        }
        if let override = columns[0] { tableau[0] = override }
        return Board(tableau: tableau, stock: [], completedRuns: [])
    }

    @Test("Enumerates every legal destination for a movable run")
    func enumeratesDestinations() {
        // Q♠ can sit on either red King; K♠Q♠ together can go nowhere.
        let b = board([
            0: [makeCard(1, .king, .spades), makeCard(2, .queen, .spades)],
            1: [makeCard(3, .king, .hearts)],
            2: [makeCard(4, .king, .diamonds)],
        ])
        let found = HintProvider().candidates(for: b)
        #expect(found.count == 2)
        #expect(found.allSatisfy { $0.sourceColumn == 0 && $0.runRange == 1..<2 })
        #expect(found.map(\.destinationColumn) == [1, 2])
    }

    @Test("Offers each legal sub-run, shortest first")
    func enumeratesSubRuns() {
        // K♠Q♠J♠ over one empty column: J, QJ, and KQJ can all move there.
        let b = board([
            0: [makeCard(1, .king, .spades), makeCard(2, .queen, .spades), makeCard(3, .jack, .spades)],
            1: [],
        ])
        let fromZero = HintProvider().candidates(for: b).filter { $0.sourceColumn == 0 }
        #expect(fromZero.map(\.runRange) == [2..<3, 1..<3, 0..<3])
        #expect(fromZero.allSatisfy { $0.destinationColumn == 1 })
    }

    @Test("Scan order is source, then run length, then destination — not strategy")
    func scanOrder() {
        // Column 0's Q♠ fits a same-suit K♠ (col 3) and an off-suit K♥ (col 1).
        // A ranked list would lead with the same-suit continuation; a scan
        // leads with the leftmost destination.
        let b = board([
            0: [makeCard(1, .king, .diamonds), makeCard(2, .queen, .spades)],
            1: [makeCard(3, .king, .hearts)],
            3: [makeCard(4, .king, .spades)],
        ])
        let found = HintProvider().candidates(for: b)
        let fromZero = found.filter { $0.sourceColumn == 0 && $0.runRange == 1..<2 }
        #expect(fromZero.map(\.destinationColumn) == [1, 3])
        // Sources come out left to right.
        #expect(found.map(\.sourceColumn) == found.map(\.sourceColumn).sorted())
    }

    @Test("An empty column accepts any run")
    func emptyColumnAcceptsAnything() {
        let b = board([0: [makeCard(1, .five, .hearts)], 1: []])
        let found = HintProvider().candidates(for: b)
        #expect(found.contains { $0.sourceColumn == 0 && $0.destinationColumn == 1 })
        // Every other column holds a 2♣, which can also move to the empty one.
        #expect(found.allSatisfy { $0.destinationColumn == 1 })
    }

    @Test("A board with no legal move yields no candidates")
    func noCandidates() {
        // Ten lone 2♣: each needs a 3 on top, and there is no empty column.
        let found = HintProvider().candidates(for: board([:]))
        #expect(found.isEmpty)
    }

    @Test("A face-down top is not movable")
    func faceDownTopIsNotMovable() {
        let b = board([
            0: [makeCard(1, .queen, .spades, up: false)],
            1: [makeCard(2, .king, .hearts)],
        ])
        #expect(HintProvider().candidates(for: b).isEmpty)
    }

    @Test("Candidate ids are unique and enumeration is pure")
    func idsUniqueAndBoardUntouched() {
        let b = board([
            0: [makeCard(1, .king, .spades), makeCard(2, .queen, .spades)],
            1: [makeCard(3, .king, .hearts)],
        ])
        let before = b
        let found = HintProvider().candidates(for: b)
        #expect(Set(found.map(\.id)).count == found.count)
        #expect(b == before)
    }
}
