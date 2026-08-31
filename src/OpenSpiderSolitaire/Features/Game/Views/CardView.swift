import SwiftUI

/// Renders a single card. **Placeholder art** — drawn in SwiftUI (rank + SF
/// Symbol suit). This is the seam for the vetted CC0 SVG deck (PRD open item):
/// swap the `face`/`back` bodies without touching layout or gestures.
struct CardView: View {
    let card: Card
    let size: CGSize

    var body: some View {
        Group {
            if card.isFaceUp { face } else { back }
        }
        .frame(width: size.width, height: size.height)
    }

    private var cornerRadius: CGFloat { size.width * 0.12 }

    private var face: some View {
        let color: Color = (card.suit == .hearts || card.suit == .diamonds) ? .red : .black
        return RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.white)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.black.opacity(0.25), lineWidth: 0.5))
            .overlay(alignment: .topLeading) { corner(color: color).padding(size.width * 0.08) }
            .overlay {
                Image(systemName: suitSymbol)
                    .font(.system(size: size.width * 0.42))
                    .foregroundStyle(color)
            }
    }

    private func corner(color: Color) -> some View {
        VStack(spacing: -size.width * 0.02) {
            Text(rankText)
                .font(.system(size: size.width * 0.34, weight: .bold, design: .rounded))
            Image(systemName: suitSymbol)
                .font(.system(size: size.width * 0.20))
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    private var back: some View {
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

    private var suitSymbol: String {
        switch card.suit {
        case .spades: return "suit.spade.fill"
        case .hearts: return "suit.heart.fill"
        case .diamonds: return "suit.diamond.fill"
        case .clubs: return "suit.club.fill"
        }
    }
}
