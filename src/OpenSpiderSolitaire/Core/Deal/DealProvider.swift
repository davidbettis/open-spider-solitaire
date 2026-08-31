import Foundation

/// Source of fresh deals for a new game. Injected into ``GameSession`` so tests
/// can supply a controlled deal.
protocol DealProvider: Sendable {
    func makeDeal<R: RandomNumberGenerator>(mode: SuitMode, using rng: inout R) -> Board
}

/// v1 deal source: shuffle the mode's 104-card multiset and lay out a standard
/// board (heights `[6,6,6,6,5,5,5,5,5,5]`, only tops face-up, 50 in stock).
///
/// **Deals are not guaranteed winnable in v1.** Guaranteed-solvable deals (via
/// an offline pre-generated pool) are a deferred later phase — see PRD → Deal
/// Generation. Because ``GameSession`` depends only on the ``DealProvider``
/// seam, swapping in a pool-backed provider later needs no other changes.
struct RandomDealProvider: DealProvider {
    func makeDeal<R: RandomNumberGenerator>(mode: SuitMode, using rng: inout R) -> Board {
        var cards: [(rank: Rank, suit: Suit)] = []
        for suit in mode.suits {
            for _ in 0..<mode.copiesPerCard {
                for raw in 1...13 { cards.append((Rank(rawValue: raw)!, suit)) }
            }
        }
        cards.shuffle(using: &rng)
        return DealFormat.board(from: cards)
    }
}
