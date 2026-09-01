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
            .overlay(alignment: .topLeading) { corner.padding(size.width * 0.08) }
            .overlay {
                Image(systemName: card.suit.symbolName)
                    .font(.system(size: size.width * 0.42))
                    .foregroundStyle(card.suit.tint)
            }
            .frame(width: size.width, height: size.height)
    }

    private var cornerRadius: CGFloat { size.width * 0.12 }

    private var corner: some View {
        VStack(spacing: -size.width * 0.02) {
            Text(rankText)
                .font(.system(size: size.width * 0.34, weight: .bold, design: .rounded))
            Image(systemName: card.suit.symbolName)
                .font(.system(size: size.width * 0.20))
        }
        .foregroundStyle(card.suit.tint)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
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
