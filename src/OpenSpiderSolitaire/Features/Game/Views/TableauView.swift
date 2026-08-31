import SwiftUI

/// The 10 tableau columns laid out in a row, sized by ``BoardLayout``.
struct TableauView: View {
    let tableau: [[Card]]
    let layout: BoardLayout
    let regionHeight: CGFloat
    let cardNamespace: Namespace.ID
    let justDealtIDs: Set<Int>

    var body: some View {
        HStack(spacing: layout.gutter) {
            ForEach(0..<BoardLayout.columnCount, id: \.self) { column in
                ColumnView(index: column,
                           cards: tableau[column],
                           layout: layout,
                           regionHeight: regionHeight,
                           cardNamespace: cardNamespace,
                           justDealtIDs: justDealtIDs)
                    // Leftmost column on top. Dealt cards fly right-to-left
                    // from the deck, so a card bound for column i crosses every
                    // column to its right; this puts it over them instead of
                    // behind. Columns never overlap at rest, so the order is
                    // invisible except in flight.
                    .zIndex(Double(BoardLayout.columnCount - column))
            }
        }
        .padding(.horizontal, layout.gutter)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
