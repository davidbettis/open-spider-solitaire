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

    // MARK: Spread (iPad)

    /// An iPad in portrait: ten columns across 1032pt leave cards only 129pt
    /// tall in a region roughly 1150pt deep, which is where a phone-tuned fan
    /// strands the whole board in a band across the top.
    private static let padPortrait = CGSize(width: 1032, height: 1150)
    /// The same iPad turned: plenty of width, and much less height to fill.
    private static let padLandscape = CGSize(width: 1366, height: 880)

    /// The shipped phone design has to be bit-identical, so `.compact` is the
    /// default and its ceiling of 1 makes the expansion a no-op.
    @Test func compactSpreadIsTheDefaultAndUnchanged() {
        let deal = Array(repeating: column(6), count: 10)
        let explicit = BoardLayout(size: Self.padPortrait, tableau: deal, spread: .compact)
        let byDefault = BoardLayout(size: Self.padPortrait, tableau: deal)
        #expect(explicit == byDefault)
        #expect(explicit.faceUpPeek == explicit.cardSize.height * BoardLayout.baseFaceUpPeek)
        #expect(explicit.faceDownPeek == explicit.cardSize.height * BoardLayout.baseFaceDownPeek)
    }

    @Test func roomySpreadFansFurtherWhenThereIsSlack() {
        let deal = Array(repeating: column(6), count: 10)
        let compact = BoardLayout(size: Self.padPortrait, tableau: deal, spread: .compact)
        let roomy = BoardLayout(size: Self.padPortrait, tableau: deal, spread: .roomy)
        #expect(roomy.cardSize == compact.cardSize)       // only the fan changes
        #expect(roomy.faceUpPeek > compact.faceUpPeek)
        #expect(roomy.faceDownPeek > compact.faceDownPeek)
        #expect(roomy.faceUpPeek > roomy.faceDownPeek)
    }

    @Test func roomySpreadIsCapped() {
        // A container far taller than any column could ask for.
        let roomy = BoardLayout(size: CGSize(width: 1032, height: 20_000),
                                tableau: Array(repeating: column(6), count: 10),
                                spread: .roomy)
        let ceiling = roomy.cardSize.height
            * BoardLayout.baseFaceUpPeek * BoardLayout.Spread.roomy.maxExpansion
        #expect(roomy.faceUpPeek <= ceiling + 0.0001)
    }

    /// The point of measuring the spread against a fixed nominal column is that
    /// the fan does **not** move as the board deepens — otherwise every deal
    /// would re-fan all ten columns.
    @Test func roomyFanHoldsStillWhileColumnsGrow() {
        let shallow = Array(repeating: column(6), count: 10)
        let deeper = Array(repeating: column(11), count: 10)
        let a = BoardLayout(size: Self.padPortrait, tableau: shallow, spread: .roomy)
        let b = BoardLayout(size: Self.padPortrait, tableau: deeper, spread: .roomy)
        #expect(a.faceUpPeek == b.faceUpPeek)
        #expect(a.faceDownPeek == b.faceDownPeek)
    }

    /// The nominal column is what the spread is sized to fill, so it has to fit.
    @Test(arguments: [padPortrait, padLandscape])
    func theNominalColumnFitsTheRegion(size: CGSize) {
        var nominal = (0..<BoardLayout.nominalFaceDownCount)
            .map { makeCard($0, .seven, .spades, up: false) }
        nominal += (BoardLayout.nominalFaceDownCount..<BoardLayout.nominalDepth)
            .map { makeCard($0, .seven, .spades, up: true) }

        let layout = BoardLayout(size: size, tableau: [nominal], spread: .roomy)
        #expect(layout.columnHeight(nominal) <= size.height + 0.5)
    }

    /// Compression solves for "exactly fills the region" from either starting
    /// fan, so a board deep enough to compress looks the same on both.
    @Test func aCompressedBoardIsTheSameEitherWay() {
        let tall = [column(40, allFaceUp: true)]
        let compact = BoardLayout(size: Self.padLandscape, tableau: tall, spread: .compact)
        let roomy = BoardLayout(size: Self.padLandscape, tableau: tall, spread: .roomy)
        #expect(abs(roomy.faceUpPeek - compact.faceUpPeek) < 0.0001)
    }
}
