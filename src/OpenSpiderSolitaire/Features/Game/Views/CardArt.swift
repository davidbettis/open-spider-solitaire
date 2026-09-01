import SwiftUI

/// Shared card presentation primitives used by both the tableau (``CardView``)
/// and the HUD (``SetSlots``, ``DeckIndicator``), so the two never drift.
/// Still **placeholder art** — see ``CardView`` for the CC0 deck seam.

extension Suit {
    /// SF Symbol for the suit pip.
    var symbolName: String {
        switch self {
        case .spades: return "suit.spade.fill"
        case .hearts: return "suit.heart.fill"
        case .diamonds: return "suit.diamond.fill"
        case .clubs: return "suit.club.fill"
        }
    }

    /// Ink colour: red for the round suits, black for the pointed ones.
    var tint: Color {
        switch self {
        case .hearts, .diamonds: return .red
        case .spades, .clubs: return .black
        }
    }
}

/// The face-down card back at an arbitrary size. All ornament is proportional
/// to the width, so it reads the same at tableau and HUD scales.
struct CardBack: View {
    let size: CGSize

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius * 0.7)
                    .strokeBorder(.white.opacity(0.6), lineWidth: max(1, size.width * 0.03))
                    .padding(size.width * 0.12)
            )
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.black.opacity(0.25), lineWidth: 0.5))
            .frame(width: size.width, height: size.height)
    }

    private var cornerRadius: CGFloat { size.width * 0.12 }
}

/// An empty card footprint: the dashed outline used for an unfilled set slot
/// and for the exhausted stock, so neither zone reflows when it empties.
struct CardOutline: View {
    let size: CGSize

    var body: some View {
        RoundedRectangle(cornerRadius: size.width * 0.12)
            .strokeBorder(Palette.placeholder, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            .frame(width: size.width, height: size.height)
    }
}

/// The face-up side of a card. Split out of ``CardView`` so ``FlippingCard``
/// can show it independently of the back.
struct CardFace: View {
    let card: Card
    let size: CGSize

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.white)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.black.opacity(0.25), lineWidth: 0.5))
            .overlay(alignment: .top) { index }
            // Decoration for the exposed card only: a covered card never shows
            // it. Nudged below the card's centre, because the index occupies
            // the top and a truly centred pip leaves the face top-heavy. Half
            // of the way to centring it in the space below the index, which
            // overcorrects and reads bottom-heavy instead.
            .overlay {
                Image(systemName: card.suit.symbolName)
                    .font(.system(size: size.width * 0.42))
                    .foregroundStyle(card.suit.tint)
                    .offset(y: CardFace.indexExtent(size) / 4)
            }
            .frame(width: size.width, height: size.height)
    }

    private var cornerRadius: CGFloat { size.width * 0.12 }

    /// How far down the card the index reaches: top padding plus its tallest
    /// row. The centre pip is balanced against this.
    static func indexExtent(_ size: CGSize) -> CGFloat { size.width * 0.44 }

    /// Rank and suit on one line, and the card's *only* index: rank against the
    /// left edge, pip against the right.
    ///
    /// One line, not stacked, because of how little of a covered card shows.
    /// `BoardLayout.faceUpPeek` reveals `cardHeight * 0.34` of each card under
    /// another, which at `aspectRatio` 1.4 is `0.476 * cardWidth`. A stacked
    /// rank-over-pip index is about `0.71 * cardWidth` tall, so the pip fell
    /// below the fold and every covered card showed a bare rank - unreadable in
    /// 2- and 4-suit, where colour alone does not identify a suit. On one line
    /// the index is `indexExtent` tall and fits inside the peek.
    private var index: some View {
        HStack(spacing: 0) {
            Text(rankText)
                .font(.system(size: size.width * 0.30, weight: .bold, design: .rounded))
            Spacer(minLength: size.width * 0.04)
            Image(systemName: card.suit.symbolName)
                .font(.system(size: size.width * 0.22))
        }
        .foregroundStyle(card.suit.tint)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.horizontal, size.width * 0.08)
        .padding(.top, size.width * 0.08)
    }

    private var rankText: String {
        switch card.rank {
        case .ace: return "A"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ten: return "10"
        default: return String(card.rank.rawValue)
        }
    }
}

/// A card mid-turn (spec §5). `Animatable` so the view can read the
/// *interpolated* angle and swap back for face at the halfway point — that
/// swap is what reads as a flip rather than a cross-fade.
struct FlippingCard: View, Animatable {
    /// 0° = fully face-up, 180° = fully face-down.
    var angle: Double
    let card: Card
    let size: CGSize

    // SwiftUI interpolates this off the main actor; reading a stored property
    // of a value type there is safe, so the conformance is nonisolated.
    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        Group {
            if angle < 90 {
                CardFace(card: card, size: size)
            } else {
                // Counter-rotate so the back is not seen mirrored.
                CardBack(size: size).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
    }
}
