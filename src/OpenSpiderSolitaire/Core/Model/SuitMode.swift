import Foundation

/// Difficulty, expressed as the number of distinct suits in play. Every mode
/// uses two full decks (104 cards) restricted to the selected suits.
enum SuitMode: Int, Codable, Sendable, Hashable, CaseIterable {
    case one = 1
    case two = 2
    case four = 4

    /// Suits present in the deck for this mode.
    var suits: [Suit] {
        switch self {
        case .one:  return [.spades]
        case .two:  return [.spades, .hearts]
        case .four: return Suit.allCases
        }
    }

    /// Copies of each `(rank, suit)` pair so the deck always totals 104 cards:
    /// 1-suit → 8, 2-suit → 4, 4-suit → 2.
    var copiesPerCard: Int { 8 / rawValue }
}
