import SwiftUI

/// The HUD's left zone: eight card-shaped slots, one per King→Ace run, filled
/// left-to-right in completion order (spec §7).
struct SetSlots: View {
    let completed: [CompletedRun]
    let layout: HUDLayout

    var body: some View {
        HStack(spacing: layout.slotSpacing) {
            ForEach(0..<HUDLayout.slotCount, id: \.self) { index in
                slot(suit(at: index))
            }
        }
        .frame(width: layout.slotsWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sets completed")
        .accessibilityValue("\(completed.count) of \(HUDLayout.slotCount)")
    }

    private func suit(at index: Int) -> Suit? {
        completed.indices.contains(index) ? completed[index].suit : nil
    }

    @ViewBuilder
    private func slot(_ suit: Suit?) -> some View {
        if let suit {
            RoundedRectangle(cornerRadius: layout.slotSize.width * 0.12)
                .fill(.white)
                .overlay {
                    Image(systemName: suit.symbolName)
                        .font(.system(size: layout.slotSize.width * 0.6))
                        .foregroundStyle(suit.tint)
                }
                .frame(width: layout.slotSize.width, height: layout.slotSize.height)
        } else {
            CardOutline(size: layout.slotSize)
        }
    }
}
