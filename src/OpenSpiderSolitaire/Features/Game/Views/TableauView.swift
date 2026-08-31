import SwiftUI

/// The 10 tableau columns laid out in a row, sized by ``BoardLayout``.
struct TableauView: View {
    let tableau: [[Card]]
    let layout: BoardLayout
    let regionHeight: CGFloat

    var body: some View {
        HStack(spacing: layout.gutter) {
            ForEach(0..<BoardLayout.columnCount, id: \.self) { column in
                ColumnView(index: column,
                           cards: tableau[column],
                           layout: layout,
                           regionHeight: regionHeight)
            }
        }
        .padding(.horizontal, layout.gutter)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
