import SwiftUI

/// The HUD's right zone: a face-down deck whose depth is the number of deals
/// still available, doubling as the deal control (spec §6.3).
///
/// It is greyed out **only** when the stock is spent. While cards remain it
/// stays live even if the deal would be refused — an empty column is explained
/// by flashing that column, not by a dead control the player can't interpret.
struct DeckIndicator: View {
    let dealsRemaining: Int
    let layout: HUDLayout
    let onDeal: () -> Void

    private var hasCardsLeft: Bool { dealsRemaining > 0 }

    var body: some View {
        Button(action: onDeal) {
            ZStack(alignment: .leading) {
                CardOutline(size: layout.slotSize)
                ForEach(0..<max(0, dealsRemaining), id: \.self) { depth in
                    CardBack(size: layout.slotSize)
                        .offset(x: CGFloat(depth) * layout.deckOffsetStep)
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
