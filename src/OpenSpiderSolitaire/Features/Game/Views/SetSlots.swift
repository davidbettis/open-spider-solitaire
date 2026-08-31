import SwiftUI

/// The HUD's left zone: eight card-shaped slots, one per King→Ace run, filled
/// left-to-right in completion order (spec §7).
///
/// The slots are **fanned** at a half-card step, which halves the row's
/// footprint and buys roughly double the slot size on a phone. The first slot
/// sits on top and is fully visible; each later slot is layered *underneath*
/// the one before it, peeking out to the right. So every slot after the first
/// shows only its right half, and the suit pip is centred in whatever strip of
/// its card is actually visible.
struct SetSlots: View {
    let completed: [CompletedRun]
    let layout: HUDLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<HUDLayout.slotCount, id: \.self) { index in
                slot(suit(at: index), at: index)
                    .offset(x: CGFloat(index) * layout.slotStep)
                    .zIndex(Double(HUDLayout.slotCount - index))   // first on top
            }
        }
        .frame(width: layout.slotsWidth, height: layout.slotSize.height, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sets completed")
        .accessibilityValue("\(completed.count) of \(HUDLayout.slotCount)")
    }

    private func suit(at index: Int) -> Suit? {
        completed.indices.contains(index) ? completed[index].suit : nil
    }

    /// The strip of slot `index` the player can actually see: the whole card
    /// for the first, the right half for every slot layered behind one.
    private func visibleWidth(at index: Int) -> CGFloat {
        index == 0 ? layout.slotSize.width : layout.slotSize.width * HUDLayout.slotOverlapStep
    }

    @ViewBuilder
    private func slot(_ suit: Suit?, at index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: layout.slotSize.width * 0.12)
        if let suit {
            shape
                .fill(.white)
                // Overlapping white cards need an edge to separate them.
                .overlay(shape.strokeBorder(.black.opacity(0.35), lineWidth: 0.5))
                // The visible strip is always flush right, so aligning the pip
                // trailing and sizing it to that strip centres it in view.
                .overlay(alignment: .trailing) {
                    Image(systemName: suit.symbolName)
                        .font(.system(size: layout.slotSize.width * 0.4))
                        .foregroundStyle(suit.tint)
                        .frame(width: visibleWidth(at: index))
                }
                .frame(width: layout.slotSize.width, height: layout.slotSize.height)
                // Cast onto the slot behind, so the stack reads as depth.
                .shadow(color: .black.opacity(0.35), radius: 1.5, x: 1.5, y: 0)
        } else {
            CardOutline(size: layout.slotSize)
        }
    }
}
