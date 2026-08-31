import SwiftUI

/// One tableau column: cards fanned by ``BoardLayout`` offsets, with a
/// full-strip background so it reads as a column and provides a stable drop
/// frame. Each card handles tap (auto-move) and drag (explicit target).
struct ColumnView: View {
    let index: Int
    let cards: [Card]
    let layout: BoardLayout
    let regionHeight: CGFloat

    @Environment(GameSession.self) private var session
    @Environment(BoardInteraction.self) private var interaction

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: layout.cardSize.width * 0.12)
                .fill(.white.opacity(0.06))
                .frame(width: layout.cardSize.width, height: regionHeight)

            ForEach(Array(cards.enumerated()), id: \.element.id) { position, card in
                cardView(card, at: position)
            }
        }
        .frame(width: layout.cardSize.width, height: regionHeight, alignment: .top)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ColumnFramesKey.self,
                                       value: [index: proxy.frame(in: .named("board"))])
            }
        )
    }

    private func cardView(_ card: Card, at position: Int) -> some View {
        let isDragging = interaction.drag.map { $0.sourceColumn == index && position >= $0.sourceIndex } ?? false
        return CardView(card: card, size: layout.cardSize)
            .offset(y: layout.cardY(index: position, in: cards))
            .zIndex(Double(position))
            .opacity(isDragging ? 0 : 1)
            .allowsHitTesting(!isDragging)
            .gesture(gesture(at: position))
    }

    /// One gesture handles both tap and drag: small movement = tap (auto-move);
    /// larger = drag to an explicit column.
    private func gesture(at position: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
            .onChanged { value in
                let moved = hypot(value.translation.width, value.translation.height)
                if interaction.drag == nil {
                    if moved > 8 {
                        interaction.beginDrag(column: index, index: position,
                                              at: value.location, board: session.state.board)
                    }
                } else {
                    interaction.updateDrag(to: value.location)
                }
            }
            .onEnded { value in
                if interaction.drag != nil {
                    interaction.updateDrag(to: value.location)
                    interaction.endDrag(session: session)
                } else {
                    _ = session.tap(column: index, index: position)   // treated as a tap
                }
            }
    }
}
