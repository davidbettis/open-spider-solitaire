import Foundation

/// One of the four French-deck suits. Spider uses a subset per difficulty
/// (see ``SuitMode``): spades only, spades+hearts, or all four.
enum Suit: Int, CaseIterable, Codable, Sendable, Hashable {
    case spades, hearts, diamonds, clubs
}

/// Card rank. `rawValue` orders Ace (1) low to King (13), matching Spider's
/// King→Ace descending runs.
enum Rank: Int, Comparable, CaseIterable, Codable, Sendable, Hashable {
    case ace = 1, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king

    static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    /// True when `self` sits directly on top of `other` in a descending run
    /// (i.e. `self` is exactly one rank lower).
    func isImmediatelyBelow(_ other: Rank) -> Bool { rawValue == other.rawValue - 1 }
}

/// A physical card instance.
///
/// `id` is a stable `0..<104` deck index that stays unique even across
/// duplicate `(rank, suit)` pairs (e.g. the eight identical Ace of Spades in
/// 1-suit mode), so duplicates remain distinguishable for animation and undo.
struct Card: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let rank: Rank
    let suit: Suit
    var isFaceUp: Bool
}
