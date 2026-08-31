import Foundation

/// Builds a standard Spider initial board from an ordered 104-card sequence.
///
/// The sequence fills the tableau column-by-column (bottom→top) for heights
/// `[6,6,6,6,5,5,5,5,5,5]`, then the 50 stock cards. Ids `0..<104` are assigned
/// by position; only column tops are face-up; stock is face-down.
enum DealFormat {
    static let cardsPerDeal = 104
    static let tableauHeights = [6, 6, 6, 6, 5, 5, 5, 5, 5, 5]   // sums to 54

    static func board(from sequence: [(rank: Rank, suit: Suit)]) -> Board {
        precondition(sequence.count == cardsPerDeal, "a deal must have 104 cards")
        var tableau: [[Card]] = []
        var index = 0
        var id = 0
        for height in tableauHeights {
            var column: [Card] = []
            for row in 0..<height {
                let card = sequence[index]
                column.append(Card(id: id, rank: card.rank, suit: card.suit, isFaceUp: row == height - 1))
                index += 1
                id += 1
            }
            tableau.append(column)
        }
        var stock: [Card] = []
        while index < cardsPerDeal {
            let card = sequence[index]
            stock.append(Card(id: id, rank: card.rank, suit: card.suit, isFaceUp: false))
            index += 1
            id += 1
        }
        return Board(tableau: tableau, stock: stock, completedRuns: [])
    }
}
