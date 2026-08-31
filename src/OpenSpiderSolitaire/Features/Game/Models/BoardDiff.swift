import Foundation

/// What changed between two boards, so the UI can pick the right motion per
/// card without re-deriving it from view state (spec §11). Pure and
/// `Sendable`; it knows nothing about SwiftUI.
///
/// The categories are disjoint by construction: a card that arrived from the
/// stock is *dealt*, not *moved*, and one that left into a completed run is
/// *cleared*, not anything else.
struct BoardDiff: Equatable, Sendable {
    /// Arrived in the tableau from the stock.
    let dealtCardIDs: Set<Int>
    /// Changed column or depth within the tableau.
    let movedCardIDs: Set<Int>
    /// Turned face-up where it lay.
    let flippedCardIDs: Set<Int>
    /// Left the tableau because its King→Ace run completed.
    let clearedCardIDs: Set<Int>

    var isEmpty: Bool {
        dealtCardIDs.isEmpty && movedCardIDs.isEmpty
            && flippedCardIDs.isEmpty && clearedCardIDs.isEmpty
    }

    static let none = BoardDiff(dealtCardIDs: [], movedCardIDs: [],
                                flippedCardIDs: [], clearedCardIDs: [])

    private init(dealtCardIDs: Set<Int>, movedCardIDs: Set<Int>,
                 flippedCardIDs: Set<Int>, clearedCardIDs: Set<Int>) {
        self.dealtCardIDs = dealtCardIDs
        self.movedCardIDs = movedCardIDs
        self.flippedCardIDs = flippedCardIDs
        self.clearedCardIDs = clearedCardIDs
    }

    init(from old: Board, to new: Board) {
        let before = BoardDiff.positions(in: old)
        let after = BoardDiff.positions(in: new)

        var dealt: Set<Int> = []
        var moved: Set<Int> = []
        var flipped: Set<Int> = []

        for (id, now) in after {
            guard let then = before[id] else {
                dealt.insert(id)          // was in the stock a moment ago
                continue
            }
            if then.column != now.column || then.index != now.index { moved.insert(id) }
            if !then.isFaceUp && now.isFaceUp { flipped.insert(id) }
        }

        // Anything that left the tableau did so by completing a run; the engine
        // has no other way to remove a card.
        let cleared = Set(before.keys).subtracting(after.keys)

        self.init(dealtCardIDs: dealt, movedCardIDs: moved,
                  flippedCardIDs: flipped, clearedCardIDs: cleared)
    }

    private struct Position {
        let column: Int
        let index: Int
        let isFaceUp: Bool
    }

    private static func positions(in board: Board) -> [Int: Position] {
        var result: [Int: Position] = [:]
        for (column, cards) in board.tableau.enumerated() {
            for (index, card) in cards.enumerated() {
                result[card.id] = Position(column: column, index: index, isFaceUp: card.isFaceUp)
            }
        }
        return result
    }
}
