import SwiftUI

/// Coordinates tableau interaction: the in-flight drag and the registry of
/// column frames used for drop hit-testing (spec §6). UI-only state; all rules
/// go through ``GameSession``/``Rules``.
@MainActor
@Observable
final class BoardInteraction {
    /// How long the empty-column flash stays up after a blocked deal.
    static let flashDuration: Duration = .milliseconds(900)

    var drag: DragState?
    var columnFrames: [Int: CGRect] = [:]

    /// Columns flashing because they blocked a deal — the one place the board
    /// gives negative feedback (spec §6.3).
    private(set) var blockedColumns: Set<Int> = []

    @ObservationIgnored private var flashTask: Task<Void, Never>?

    /// Begin dragging the run at `(column, index)` if it is a valid movable run.
    func beginDrag(column: Int, index: Int, at location: CGPoint, board: Board) {
        guard drag == nil,
              board.tableau.indices.contains(column),
              index >= 0, index < board.tableau[column].count,
              Rules.isMovableRun(board.tableau[column], from: index)
        else { return }
        drag = DragState(sourceColumn: column, sourceIndex: index,
                         cards: Array(board.tableau[column][index...]), location: location)
    }

    func updateDrag(to location: CGPoint) { drag?.location = location }

    /// Flash every empty column, to explain a deal the engine just refused.
    /// A board with no empty column has nothing to explain, so this is a no-op.
    func flashEmptyColumns(board: Board) {
        let empties = Set(board.tableau.indices.filter { board.tableau[$0].isEmpty })
        guard !empties.isEmpty else { return }
        blockedColumns = empties
        flashTask?.cancel()
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: BoardInteraction.flashDuration)
            guard !Task.isCancelled, let self else { return }
            self.clearFlash()
        }
    }

    func clearFlash() {
        flashTask?.cancel()
        flashTask = nil
        blockedColumns = []
    }

    /// Drop: move the run to the column under the pointer, or snap back (no-op)
    /// if there is no legal target. Illegal moves are silently rejected by the
    /// engine (spec: no invalid-move feedback).
    func endDrag(session: GameSession) {
        defer { drag = nil }
        guard let drag else { return }
        let x = drag.location.x
        guard let target = columnFrames.first(where: { $0.value.minX <= x && x <= $0.value.maxX })?.key,
              target != drag.sourceColumn
        else { return }
        _ = session.move(from: drag.sourceColumn, index: drag.sourceIndex, to: target)
    }
}

/// Publishes each column's frame (in the "board" coordinate space) for drop
/// hit-testing.
struct ColumnFramesKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
