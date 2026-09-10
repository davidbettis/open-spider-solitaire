import SwiftUI

/// One tableau column: cards fanned by ``BoardLayout`` offsets, with a
/// full-strip background so it reads as a column and provides a stable drop
/// frame. Each card handles tap (auto-move) and drag (explicit target), and the
/// strip below them takes a tap for the column's top card (see ``stripTap``).
struct ColumnView: View {
    let index: Int
    let cards: [Card]
    let layout: BoardLayout
    let regionHeight: CGFloat
    /// Shared with every other column so a card gliding between them is matched
    /// by its stable `Card.id` (spec §5.1).
    let cardNamespace: Namespace.ID
    /// Cards this deal just delivered, so each column's arrival can be offset
    /// in time and the row lands as a ripple rather than all at once.
    let justDealtIDs: Set<Int>

    @Environment(GameSession.self) private var session
    @Environment(BoardInteraction.self) private var interaction

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: layout.cardSize.width * 0.12)
                .fill(Palette.columnStrip)
                .frame(width: layout.cardSize.width, height: regionHeight)
                .onTapGesture(perform: stripTap)

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

    /// A tap on the bare strip plays the column's **top card**, exactly as
    /// tapping that card does.
    ///
    /// The strip sits under the cards, so this only ever receives what falls
    /// through them — the run of empty column below the fan, which is most of
    /// the column for most of a game (a phone's opening deal leaves roughly four
    /// fifths of it bare). That turns the top card's target from one card into
    /// the whole column, which matters on a phone, where ten columns leave each
    /// card narrower than the 44pt a fingertip wants.
    ///
    /// **Tap only, deliberately.** The card gestures pick up a run on a drag;
    /// the strip does not, because there is nothing under the finger to pick up
    /// — dragging from bare board and having a card leap out of the fan to
    /// follow it would be a surprise, not a shortcut.
    ///
    /// Both degenerate cases are inert rather than special-cased: an empty
    /// column asks for index `-1`, and a face-down top is not a movable run, and
    /// ``Rules/autoMoveDestination(board:column:index:)`` refuses each.
    private func stripTap() {
        withAnimation(Motion.glide) {
            _ = session.tap(column: index, index: cards.count - 1)
        }
    }

    private func cardView(_ card: Card, at position: Int) -> some View {
        let isDragging = interaction.drag.map { $0.sourceColumn == index && position >= $0.sourceIndex } ?? false
        return CardView(card: card, size: layout.cardSize,
                        isCovered: position < cards.count - 1)
            .matchedGeometryEffect(id: card.id, in: cardNamespace)
            .transaction { transaction in
                guard justDealtIDs.contains(card.id) else { return }
                transaction.animation = Motion.deal
                    .delay(Double(index) * Motion.dealStagger)
            }
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
                    withAnimation(Motion.glide) { interaction.endDrag(session: session) }
                } else {
                    // Treated as a tap: the run glides to its auto-destination.
                    withAnimation(Motion.glide) { _ = session.tap(column: index, index: position) }
                }
            }
    }
}
