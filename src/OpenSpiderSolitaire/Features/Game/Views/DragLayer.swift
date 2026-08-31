import SwiftUI

/// Renders the run currently being dragged, following the pointer (spec §6.2).
/// Non-interactive — it's a visual only; the real cards stay hidden in place.
struct DragLayer: View {
    let drag: DragState
    let layout: BoardLayout

    var body: some View {
        let stackHeight = layout.cardSize.height + CGFloat(drag.cards.count - 1) * layout.faceUpPeek
        ZStack(alignment: .top) {
            ForEach(Array(drag.cards.enumerated()), id: \.element.id) { position, card in
                CardView(card: card, size: layout.cardSize)
                    .offset(y: CGFloat(position) * layout.faceUpPeek)
                    .zIndex(Double(position))
            }
        }
        .frame(width: layout.cardSize.width, height: stackHeight, alignment: .top)
        // Center the grabbed (first) card under the pointer.
        .position(x: drag.location.x, y: drag.location.y + (stackHeight - layout.cardSize.height) / 2)
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        .allowsHitTesting(false)
    }
}
