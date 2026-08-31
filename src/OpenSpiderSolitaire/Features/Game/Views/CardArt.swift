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
            .strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            .frame(width: size.width, height: size.height)
    }
}
