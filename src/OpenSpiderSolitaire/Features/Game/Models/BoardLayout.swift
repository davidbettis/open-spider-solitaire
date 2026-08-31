import CoreGraphics

/// Pure, testable layout math for the tableau (spec §5). Computes a uniform card
/// size and per-card vertical offsets from the container size and the current
/// columns, compressing the fan so the tallest column fits without scrolling.
struct BoardLayout: Equatable {
    static let columnCount = 10
    /// Card height / width. Placeholder until the real deck pins it (spec AI-1).
    static let aspectRatio: CGFloat = 1.4

    let cardSize: CGSize
    let gutter: CGFloat
    let faceUpPeek: CGFloat
    let faceDownPeek: CGFloat
    let topInset: CGFloat

    init(size: CGSize, tableau: [[Card]]) {
        let gutter = max(2, size.width * 0.008)
        let usableWidth = size.width - gutter * CGFloat(BoardLayout.columnCount + 1)
        let cardWidth = max(1, usableWidth / CGFloat(BoardLayout.columnCount))
        let cardHeight = cardWidth * BoardLayout.aspectRatio
        let topInset = gutter

        // Base fan spacing, then compress uniformly if the tallest column
        // overflows the available height (spec §5: prefer compression to scroll).
        var faceUp = cardHeight * 0.34
        var faceDown = cardHeight * 0.18

        func extent(_ column: [Card], up: CGFloat, down: CGFloat) -> CGFloat {
            guard column.count > 1 else { return cardHeight }
            let spacing = column.dropLast().reduce(CGFloat.zero) { $0 + ($1.isFaceUp ? up : down) }
            return cardHeight + spacing
        }

        let available = max(cardHeight, size.height - topInset)
        let tallest = tableau.map { extent($0, up: faceUp, down: faceDown) }.max() ?? cardHeight
        if tallest > available, tallest > cardHeight {
            let scale = max(0.30, (available - cardHeight) / (tallest - cardHeight))
            faceUp *= scale
            faceDown *= scale
        }

        self.cardSize = CGSize(width: cardWidth, height: cardHeight)
        self.gutter = gutter
        self.topInset = topInset
        self.faceUpPeek = max(cardHeight * 0.05, faceUp)      // hard minimums
        self.faceDownPeek = max(cardHeight * 0.03, faceDown)
    }

    /// Left edge of a column within the tableau region.
    func columnX(_ column: Int) -> CGFloat {
        gutter + CGFloat(column) * (cardSize.width + gutter)
    }

    /// Top edge (Y) of the card at `index` within `column`, accumulating the
    /// peek of each card above it.
    func cardY(index: Int, in column: [Card]) -> CGFloat {
        var y = topInset
        for k in 0..<min(index, column.count) {
            y += column[k].isFaceUp ? faceUpPeek : faceDownPeek
        }
        return y
    }

    /// Total laid-out height of a column.
    func columnHeight(_ column: [Card]) -> CGFloat {
        guard !column.isEmpty else { return cardSize.height + topInset }
        return cardY(index: column.count - 1, in: column) + cardSize.height
    }

    /// Height needed by the tallest column (for sizing the tableau region).
    func contentHeight(_ tableau: [[Card]]) -> CGFloat {
        (tableau.map(columnHeight).max() ?? cardSize.height) + topInset
    }
}
