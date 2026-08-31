import SwiftUI

/// The HUD's right zone: a face-down deck whose depth is the number of deals
/// still available, doubling as the deal control (spec §6.3).
///
/// It is greyed out **only** when the stock is spent. While cards remain it
/// stays live even if the deal would be refused — an empty column is explained
/// by flashing that column, not by a dead control the player can't interpret.
struct DeckIndicator: View {
    let dealsRemaining: Int
    /// The ten cards the next deal will hand out, rendered here stacked so
    /// each has a frame to fly *from* when it lands in a column (spec §5).
    let nextDeal: [Card]
    let layout: HUDLayout
    let cardNamespace: Namespace.ID
    let onDeal: () -> Void

    private var hasCardsLeft: Bool { dealsRemaining > 0 }

    var body: some View {
        Button(action: onDeal) {
            ZStack(alignment: .leading) {
                CardOutline(size: layout.slotSize)
                // A single card, fixed whatever the count: the badge says how
                // many deals are left, so the deck neither grows nor shrinks.
                if hasCardsLeft {
                    CardBack(size: layout.slotSize)
                }
                // The next deal's actual cards, stacked on the top back so the
                // deck looks unchanged — but each is a matched-geometry source.
                ForEach(nextDeal, id: \.id) { card in
                    // Always shown face-down: a card still in the deck has not
                    // been turned over yet, whatever it will be on landing.
                    CardView(card: faceDown(card), size: layout.slotSize)
                        .matchedGeometryEffect(id: card.id, in: cardNamespace)
                }
            }
            // Always the deepest footprint, so the bar holds still as it drains.
            .frame(width: layout.deckWidth, height: layout.slotSize.height, alignment: .leading)
            .overlay(alignment: .bottomTrailing) { badge }
        }
        .buttonStyle(.plain)
        .disabled(!hasCardsLeft)
        .opacity(hasCardsLeft ? 1 : 0.45)
        .accessibilityLabel("Deal")
        .accessibilityValue("\(dealsRemaining) deals remaining")
    }

    private func faceDown(_ card: Card) -> Card {
        Card(id: card.id, rank: card.rank, suit: card.suit, isFaceUp: false)
    }

    private var badge: some View {
        Text("\(dealsRemaining)")
            .font(.caption2.bold().monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .background(Capsule().fill(.black.opacity(0.7)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 0.5))
            .offset(x: 3, y: 3)
    }
}
