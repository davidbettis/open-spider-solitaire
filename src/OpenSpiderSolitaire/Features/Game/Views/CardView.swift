import SwiftUI

/// Renders a single card. **Placeholder art** — drawn in SwiftUI (rank + SF
/// Symbol suit). This is the seam for the vetted CC0 SVG deck (PRD open item):
/// swap the `face` body and ``CardBack`` without touching layout or gestures.
/// The suit symbol/colour mapping is shared via ``CardArt``.
struct CardView: View {
    let card: Card
    let size: CGSize

    var body: some View {
        Group {
            if card.isFaceUp { face } else { CardBack(size: size) }
        }
        .frame(width: size.width, height: size.height)
    }

    private var cornerRadius: CGFloat { size.width * 0.12 }

    private var face: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.white)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.black.opacity(0.25), lineWidth: 0.5))
            .overlay(alignment: .topLeading) { corner.padding(size.width * 0.08) }
            .overlay {
                Image(systemName: card.suit.symbolName)
                    .font(.system(size: size.width * 0.42))
                    .foregroundStyle(card.suit.tint)
            }
    }

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
