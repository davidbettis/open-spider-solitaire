import Foundation

/// The pure forward rules engine for Spider Solitaire. All methods are static
/// and operate on value types, so they are deterministic and trivially testable.
///
/// Column convention: index 0 is the bottom, `last` is the top.
enum Rules {

    // MARK: Movable runs

    /// Length of the maximal movable run at the top of `column`: the run of
    /// face-up, same-suit, strictly-descending-by-one cards ending at the top.
    /// Returns 0 for an empty column or a face-down top.
    static func topRunLength(_ column: [Card]) -> Int {
        guard let top = column.last, top.isFaceUp else { return 0 }
        var length = 1
        var index = column.count - 1
        while index - 1 >= 0 {
            let lower = column[index]       // nearer the top (lower rank)
            let higher = column[index - 1]  // nearer the bottom (should be one higher)
            guard higher.isFaceUp,
                  higher.suit == lower.suit,
                  higher.rank.rawValue == lower.rank.rawValue + 1
            else { break }
            length += 1
            index -= 1
        }
        return length
    }

    /// Whether the slice from `index` to the top of `column` is a valid movable
    /// run (contiguous, same-suit, descending, face-up).
    static func isMovableRun(_ column: [Card], from index: Int) -> Bool {
        guard index >= 0, index < column.count else { return false }
        return (column.count - index) <= topRunLength(column)
    }

    // MARK: Placement

    /// Whether `run` (ordered bottom→top; `first` is the highest card) may be
    /// placed on `column`: onto an empty column always, otherwise onto a top
    /// card exactly one rank higher (any suit).
    static func canPlace(run: ArraySlice<Card>, onto column: [Card]) -> Bool {
        guard let highest = run.first else { return false }
        guard let dest = column.last else { return true } // empty column
        return dest.isFaceUp && dest.rank.rawValue == highest.rank.rawValue + 1
    }

    // MARK: Applying moves

    /// Apply a forward `move` to `board` in place, running the clear-and-flip
    /// fixpoint afterward. Returns `false` (leaving `board` unchanged) if the
    /// move is illegal.
    @discardableResult
    static func apply(_ move: Move, to board: inout Board) -> Bool {
        switch move {
        case let .relocate(from, count, to):
            guard from != to,
                  board.tableau.indices.contains(from),
                  board.tableau.indices.contains(to),
                  count > 0,
                  count <= topRunLength(board.tableau[from])
            else { return false }

            let source = board.tableau[from]
            let start = source.count - count
            let run = source[start...]
            guard canPlace(run: run, onto: board.tableau[to]) else { return false }

            let moving = Array(run)
            board.tableau[from].removeLast(count)
            board.tableau[to].append(contentsOf: moving)
            applyClearsAndFlips(&board)
            return true

        case .deal:
            guard board.dealsRemaining > 0 else { return false }
            guard !board.tableau.contains(where: \.isEmpty) else { return false }

            let dealt = board.stock.suffix(10)
            for (offset, card) in dealt.enumerated() {
                var faceUp = card
                faceUp.isFaceUp = true
                board.tableau[offset].append(faceUp)
            }
            board.stock.removeLast(10)
            applyClearsAndFlips(&board)
            return true
        }
    }

    // MARK: Clears & flips

    /// Repeatedly clear completed King→Ace runs and flip newly exposed
    /// face-down tops until the board is stable. Called after every move; a
    /// single deal can complete runs in several columns.
    static func applyClearsAndFlips(_ board: inout Board) {
        var changed = true
        while changed {
            changed = false
            for column in board.tableau.indices {
                // Reveal a face-down top.
                if let topIndex = board.tableau[column].indices.last,
                   !board.tableau[column][topIndex].isFaceUp {
                    board.tableau[column][topIndex].isFaceUp = true
                    changed = true
                }
                // Clear a completed run sitting on top.
                let cards = board.tableau[column]
                if cards.count >= 13 {
                    let slice = cards[(cards.count - 13)...]
                    if isCompleteRun(slice) {
                        board.completedRuns.append(
                            CompletedRun(cardIDs: slice.map(\.id), suit: slice.first!.suit)
                        )
                        board.tableau[column].removeLast(13)
                        changed = true
                    }
                }
            }
        }
    }

    /// Whether `slice` (ordered bottom→top) is a complete face-up King→Ace
    /// same-suit run.
    static func isCompleteRun(_ slice: ArraySlice<Card>) -> Bool {
        guard slice.count == 13 else { return false }
        let cards = Array(slice)
        let suit = cards[0].suit
        for (offset, card) in cards.enumerated() {
            guard card.isFaceUp, card.suit == suit, card.rank.rawValue == 13 - offset
            else { return false }
        }
        return true
    }

    // MARK: Single-tap auto-move

    /// Best legal destination column for the movable run beginning at
    /// `(column, index)`, by priority: same-suit continuation → any legal
    /// placement → empty column, leftmost within a tier. `nil` if the run is
    /// invalid or has no legal destination.
    static func autoMoveDestination(board: Board, column: Int, index: Int) -> Int? {
        guard board.tableau.indices.contains(column),
              isMovableRun(board.tableau[column], from: index)
        else { return nil }

        let run = board.tableau[column][index...]
        let highest = run.first!

        var sameSuit: Int?
        var anyLegal: Int?
        var empty: Int?

        for dest in board.tableau.indices where dest != column {
            let destColumn = board.tableau[dest]
            if destColumn.isEmpty {
                if empty == nil { empty = dest }
            } else if canPlace(run: run, onto: destColumn) {
                if destColumn.last!.suit == highest.suit {
                    if sameSuit == nil { sameSuit = dest }
                } else if anyLegal == nil {
                    anyLegal = dest
                }
            }
        }
        return sameSuit ?? anyLegal ?? empty
    }
}
