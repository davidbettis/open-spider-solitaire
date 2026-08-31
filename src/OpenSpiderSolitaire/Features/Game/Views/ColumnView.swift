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
        .overlay(alignment: .top) { blockedFlash }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ColumnFramesKey.self,
                                       value: [index: proxy.frame(in: .named("board"))])
            }
        )
    }

    /// Flashes red when this empty column is what refused a deal (spec §6.3).
    /// Sized to one card so it reads as "a card belongs here", not "this whole
    /// strip is wrong".
    @ViewBuilder
    private var blockedFlash: some View {
        let isBlocked = interaction.blockedColumns.contains(index)
        RoundedRectangle(cornerRadius: layout.cardSize.width * 0.12)
            // Enough opacity to read as red over the dark felt — a lighter
            // wash blends to olive against the green.
            .fill(.red.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: layout.cardSize.width * 0.12)
                    .strokeBorder(.red, lineWidth: max(2, layout.cardSize.width * 0.05))
            )
            .frame(width: layout.cardSize.width, height: layout.cardSize.height)
            .offset(y: layout.topInset)
            .opacity(isBlocked ? 1 : 0)
            .animation(.easeInOut(duration: 0.15).repeatCount(5, autoreverses: true),
                       value: isBlocked)
            .allowsHitTesting(false)
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
