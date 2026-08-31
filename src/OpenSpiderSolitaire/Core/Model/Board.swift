import Foundation

/// A completed King→Ace same-suit run cleared from the tableau. Identity is
/// retained (the 13 card ids) so undo can restore it and the win screen can
/// animate it.
struct CompletedRun: Hashable, Codable, Sendable {
    /// The 13 card ids, ordered King (bottom) → Ace (top).
    let cardIDs: [Int]
    let suit: Suit
}

/// The mutable-by-value core state: the tableau, the stock, and the runs
/// cleared so far. This is the unit the undo stack snapshots (see ``GameState``).
struct Board: Hashable, Codable, Sendable {
    /// Exactly 10 columns. Within a column, index 0 is the bottom, the last
    /// element is the top (the card the player interacts with).
    var tableau: [[Card]]

    /// Remaining stock, dealt from the end. `count` is always a multiple of 10.
    var stock: [Card]

    /// Runs cleared so far. `count == 8` means the game is won.
    var completedRuns: [CompletedRun]

    /// Number of full 10-card stock deals still available.
    var dealsRemaining: Int { stock.count / 10 }

    /// True once all eight runs have been cleared.
    var isWon: Bool { completedRuns.count == 8 }
}
