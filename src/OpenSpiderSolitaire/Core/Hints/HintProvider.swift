import Foundation

/// One suggested move: a movable run in `sourceColumn`, and a column it may
/// legally go to. Preview-only — nothing here mutates the board.
struct HintCandidate: Identifiable, Hashable, Sendable {
    /// Position in the enumeration, so the UI can key animations off it.
    let id: Int
    let sourceColumn: Int
    /// Indices of the suggested run within its source column (bottom→top).
    let runRange: Range<Int>
    let destinationColumn: Int
}

/// Enumerates every legal next move on a board (spec §4.1).
///
/// Deliberately **not** strategic: it reports the moves that exist and leaves
/// the judgement to the player. Order is a plain scan — source column left to
/// right, shortest run first within a column, then destination left to right —
/// so the cycle is predictable rather than ranked. Pure and `Sendable`; all
/// legality comes from ``Rules``.
struct HintProvider: Sendable {
    func candidates(for board: Board) -> [HintCandidate] {
        var result: [HintCandidate] = []
        var seen: Set<Key> = []

        for source in board.tableau.indices {
            let column = board.tableau[source]
            let runLength = Rules.topRunLength(column)
            guard runLength > 0 else { continue }

            // Every legal sub-run of the movable top run, shortest (the top
            // card by itself) first.
            for length in 1...runLength {
                let start = column.count - length
                let run = column[start...]

                for destination in board.tableau.indices where destination != source {
                    guard Rules.canPlace(run: run, onto: board.tableau[destination]) else { continue }
                    // Defensive: the scan cannot repeat a triple, but the
                    // spec calls for de-duplication explicitly.
                    guard seen.insert(Key(source: source, start: start, destination: destination)).inserted
                    else { continue }
                    result.append(
                        HintCandidate(id: result.count,
                                      sourceColumn: source,
                                      runRange: start..<column.count,
                                      destinationColumn: destination)
                    )
                }
            }
        }
        return result
    }

    private struct Key: Hashable {
        let source: Int
        let start: Int
        let destination: Int
    }
}
