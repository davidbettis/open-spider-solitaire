import CoreGraphics

/// Pure, testable layout math for the tableau (spec §5). Computes a uniform card
/// size and per-card vertical offsets from the container size and the current
/// columns, compressing the fan so the tallest column fits without scrolling.
struct BoardLayout: Equatable {
    static let columnCount = 10
    /// Card height / width. Placeholder until the real deck pins it (spec AI-1).
    static let aspectRatio: CGFloat = 1.4

    /// How much of the card beneath shows through, as a fraction of card
    /// height, before ``Spread`` widens it or compression narrows it.
    static let baseFaceUpPeek: CGFloat = 0.34
    static let baseFaceDownPeek: CGFloat = 0.18

    /// How far the fan is allowed to spread down the column.
    ///
    /// Ten columns want a wide, short area, so on an iPad — and above all in
    /// portrait, where the container is 4:3 the *tall* way — a fan tuned for a
    /// phone leaves the whole board stranded in a band across the top. `roomy`
    /// widens it to fill the room instead.
    ///
    /// This is an idiom decision, not a size one, which is why it is passed in
    /// rather than inferred from `size`: a phone in portrait has just as much
    /// proportional slack (its opening deal fills about a sixth of the region)
    /// and is deliberately left alone. That fan is the shipped, tuned design;
    /// `compact` reproduces it exactly, since its ceiling of 1 makes the
    /// expansion below a no-op.
    enum Spread {
        case compact
        case roomy

        /// Ceiling on the expansion, so a very tall container spreads the fan
        /// generously but never deals the cards out into a disconnected ladder.
        var maxExpansion: CGFloat {
            switch self {
            case .compact: return 1
            case .roomy: return 2.0
            }
        }
    }

    /// The column the roomy fan is sized to fill: deep enough to be worth
    /// planning for, with about half of it still face-down. Sizing to the
    /// opening deal instead would fill the screen at the cost of re-fanning
    /// the whole board on every deal; sizing to this keeps the fan **fixed**
    /// for as long as no column outgrows it, which is most of a game.
    static let nominalDepth = 16
    static let nominalFaceDownCount = 7

    let cardSize: CGSize
    let gutter: CGFloat
    let faceUpPeek: CGFloat
    let faceDownPeek: CGFloat
    let topInset: CGFloat

    init(size: CGSize, tableau: [[Card]], spread: Spread = .compact) {
        let gutter = max(2, size.width * 0.008)
        let usableWidth = size.width - gutter * CGFloat(BoardLayout.columnCount + 1)
        let cardWidth = max(1, usableWidth / CGFloat(BoardLayout.columnCount))
        let cardHeight = cardWidth * BoardLayout.aspectRatio
        let topInset = gutter

        let available = max(cardHeight, size.height - topInset)

        // Spread the base fan until a nominal deep column fills the region,
        // then stop. `available` and `cardHeight` both come from the container,
        // so this factor does not move with the board — the fan holds still
        // until a column actually outgrows the region and compression starts.
        let expansion = min(spread.maxExpansion,
                            max(1, available / BoardLayout.nominalExtent(cardHeight: cardHeight)))
        var faceUp = cardHeight * BoardLayout.baseFaceUpPeek * expansion
        var faceDown = cardHeight * BoardLayout.baseFaceDownPeek * expansion

        func extent(_ column: [Card], up: CGFloat, down: CGFloat) -> CGFloat {
            guard column.count > 1 else { return cardHeight }
            let spacing = column.dropLast().reduce(CGFloat.zero) { $0 + ($1.isFaceUp ? up : down) }
            return cardHeight + spacing
        }

        // Compress uniformly if the tallest column overflows the available
        // height (spec §5: prefer compression to scroll). A board deep enough
        // to compress lands on the same fan whether or not it was spread
        // first — compression solves for "exactly fills `available`" either
        // way — so the spread above only ever affects boards with slack.
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

    /// Height of the nominal deep column at the base fan — the yardstick the
    /// roomy spread is measured against.
    static func nominalExtent(cardHeight: CGFloat) -> CGFloat {
        let faceUpCount = CGFloat(nominalDepth - 1 - nominalFaceDownCount)
        return cardHeight * (1
                             + CGFloat(nominalFaceDownCount) * baseFaceDownPeek
                             + faceUpCount * baseFaceUpPeek)
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
