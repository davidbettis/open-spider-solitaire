import SwiftUI

/// Renders the current hint (spec §4.2): a translucent ghost of the suggested
/// run gliding from where it sits to the column it could go to, with a ring on
/// the destination. Non-interactive, and the real cards never move — the board
/// is untouched.
struct HintLayer: View {
    let candidate: HintCandidate
    let board: Board
    let layout: BoardLayout

    @State private var atDestination = false

    var body: some View {
        if let run = runCards {
            ZStack(alignment: .topLeading) {
                destinationRing
                ghost(run)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
            .task(id: candidate.id) {
                atDestination = false
                // Let the reset land in its own frame, so the glide always
                // starts from the source rather than being coalesced away.
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.55)) { atDestination = true }
            }
        }
    }

    // MARK: Geometry

    /// The suggested cards, or `nil` if the board moved out from under the
    /// candidate (the controller invalidates, but rendering must not trap).
    private var runCards: [Card]? {
        guard board.tableau.indices.contains(candidate.sourceColumn) else { return nil }
        let column = board.tableau[candidate.sourceColumn]
        guard !candidate.runRange.isEmpty,
              candidate.runRange.lowerBound >= 0,
              candidate.runRange.upperBound <= column.count
        else { return nil }
        return Array(column[candidate.runRange])
    }

    private var sourceOrigin: CGPoint {
        let column = board.tableau[candidate.sourceColumn]
        return CGPoint(x: layout.columnX(candidate.sourceColumn),
                       y: layout.cardY(index: candidate.runRange.lowerBound, in: column))
    }

    /// Where the run would land: the next free slot on the destination column.
    private var destinationOrigin: CGPoint {
        guard board.tableau.indices.contains(candidate.destinationColumn) else { return .zero }
        let column = board.tableau[candidate.destinationColumn]
        return CGPoint(x: layout.columnX(candidate.destinationColumn),
                       y: layout.cardY(index: column.count, in: column))
    }

    // MARK: Pieces

    private func ghost(_ run: [Card]) -> some View {
        let origin = atDestination ? destinationOrigin : sourceOrigin
        let height = layout.cardSize.height + CGFloat(run.count - 1) * layout.faceUpPeek
        return ZStack(alignment: .top) {
            ForEach(Array(run.enumerated()), id: \.element.id) { position, card in
                CardView(card: card, size: layout.cardSize,
                         isCovered: position < run.count - 1)
                    .offset(y: CGFloat(position) * layout.faceUpPeek)
                    .zIndex(Double(position))
            }
        }
        .frame(width: layout.cardSize.width, height: height, alignment: .top)
        .opacity(0.85)
        .shadow(color: .yellow.opacity(0.9), radius: 10)
        .offset(x: origin.x, y: origin.y)
    }

    private var destinationRing: some View {
        RoundedRectangle(cornerRadius: layout.cardSize.width * 0.12)
            .strokeBorder(.yellow.opacity(0.9), lineWidth: max(2, layout.cardSize.width * 0.04))
            .frame(width: layout.cardSize.width, height: layout.cardSize.height)
            .offset(x: destinationOrigin.x, y: destinationOrigin.y)
    }
}
