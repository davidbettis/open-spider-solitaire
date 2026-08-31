import Testing
@testable import OpenSpiderSolitaire

@Suite struct DealFormatTests {

    private func sampleSequence(mode: SuitMode, seed: UInt64) -> [(rank: Rank, suit: Suit)] {
        var rng = SplitMix64(seed: seed)
        var cards: [(rank: Rank, suit: Suit)] = []
        for suit in mode.suits {
            for _ in 0..<mode.copiesPerCard {
                for raw in 1...13 { cards.append((Rank(rawValue: raw)!, suit)) }
            }
        }
        cards.shuffle(using: &rng)
        return cards
    }

    @Test(arguments: [SuitMode.one, .two, .four])
    func boardHasStandardStructure(mode: SuitMode) {
        let board = DealFormat.board(from: sampleSequence(mode: mode, seed: 1))
        #expect(board.tableau.map(\.count).sorted(by: >) == [6, 6, 6, 6, 5, 5, 5, 5, 5, 5])
        #expect(board.stock.count == 50)
        #expect(board.completedRuns.isEmpty)

        for column in board.tableau {
            #expect(column.last?.isFaceUp == true)              // only tops face-up
            for card in column.dropLast() { #expect(!card.isFaceUp) }
        }

        let all = board.tableau.flatMap { $0 } + board.stock
        #expect(all.count == 104)
        #expect(Set(all.map(\.id)) == Set(0..<104))             // unique ids
        for suit in mode.suits {
            for raw in 1...13 {
                let count = all.filter { $0.suit == suit && $0.rank.rawValue == raw }.count
                #expect(count == mode.copiesPerCard)             // correct multiset
            }
        }
    }
}
