import Testing
import CoreGraphics
@testable import OpenSpiderSolitaire

@Suite struct BoardLayoutTests {

    private func column(_ n: Int, allFaceUp: Bool = false) -> [Card] {
        (0..<n).map { makeCard($0, .seven, .spades, up: allFaceUp || $0 == n - 1) }
    }

    private var emptyTableau: [[Card]] { Array(repeating: [], count: 10) }

    @Test func tenColumnsFitTheWidth() {
        let layout = BoardLayout(size: CGSize(width: 400, height: 800), tableau: emptyTableau)
        let used = layout.cardSize.width * 10 + layout.gutter * 11
        #expect(used <= 400.5)
        #expect(layout.cardSize.width > 0)
        #expect(layout.cardSize.height > layout.cardSize.width)   // portrait card
    }

    @Test func faceUpPeekExceedsFaceDown() {
        let layout = BoardLayout(size: CGSize(width: 400, height: 800), tableau: emptyTableau)
        #expect(layout.faceUpPeek > layout.faceDownPeek)
        #expect(layout.faceDownPeek > 0)
    }

    @Test func cardYIncreasesDownTheColumn() {
        let col = column(6)
        let layout = BoardLayout(size: CGSize(width: 400, height: 900), tableau: [col])
        var previous = -CGFloat.infinity
        for index in col.indices {
            let y = layout.cardY(index: index, in: col)
            #expect(y > previous)
            previous = y
        }
    }

    @Test func compressesToFitATallColumn() {
        let tall = column(40, allFaceUp: true)
        let short = column(1, allFaceUp: true)
        let compressed = BoardLayout(size: CGSize(width: 400, height: 300), tableau: [tall])
        let roomy = BoardLayout(size: CGSize(width: 400, height: 300), tableau: [short])
        #expect(compressed.faceUpPeek < roomy.faceUpPeek)
    }

    @Test func emptyColumnHeightIsOneCard() {
        let layout = BoardLayout(size: CGSize(width: 400, height: 800), tableau: emptyTableau)
        #expect(layout.columnHeight([]) == layout.cardSize.height + layout.topInset)
    }
}
