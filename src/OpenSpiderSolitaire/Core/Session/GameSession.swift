import Foundation
import Observation

/// The observable game session the UI binds to: it owns the ``GameState``,
/// exposes intents (tap / move / deal / undo / auto-complete / new game), and
/// drives timing. All rule logic lives in ``Rules``; scoring is derived by
/// ``Scoring``. Undo uses board snapshots (spec §9).
@MainActor
@Observable
final class GameSession {
    private(set) var state: GameState
    private let clock: any TimeSource
    private let dealProvider: any DealProvider

    /// Wall-clock instant the timer last resumed, or `nil` while paused.
    /// `state.elapsed` holds the accumulated time up to that instant.
    @ObservationIgnored private var runningSince: TimeInterval?

    // MARK: Init

    /// Start a fresh, solvable game in `mode`, drawn from the bundled deal pool.
    init(
        mode: SuitMode,
        rng: inout some RandomNumberGenerator,
        dealProvider: any DealProvider = RandomDealProvider(),
        clock: any TimeSource = SystemClock()
    ) {
        self.dealProvider = dealProvider
        self.clock = clock
        self.state = GameState(mode: mode, board: dealProvider.makeDeal(mode: mode, using: &rng))
    }

    /// Resume a persisted game. Timing continues from the saved `elapsed`.
    init(
        resuming state: GameState,
        dealProvider: any DealProvider = RandomDealProvider(),
        clock: any TimeSource = SystemClock()
    ) {
        self.state = state
        self.dealProvider = dealProvider
        self.clock = clock
        if state.timerStarted && !state.board.isWon { runningSince = clock.now }
    }

    // MARK: Derived, UI-facing

    var displayScore: Int { Scoring.displayScore(for: state) }
    var isWon: Bool { state.board.isWon }

    /// Completed King→Ace sets cleared so far (0…8). The game is won at 8.
    var completedSets: Int { state.board.completedRuns.count }
    static let totalSets = 8
    var canUndo: Bool { !state.undoStack.isEmpty }
    var canDeal: Bool {
        state.board.dealsRemaining > 0 && !state.board.tableau.contains(where: \.isEmpty)
    }

    /// Total play time including any time accrued since the last resume.
    var elapsed: TimeInterval {
        guard let since = runningSince else { return state.elapsed }
        return state.elapsed + (clock.now - since)
    }

    /// Auto-complete is available when nothing is hidden and the board can be
    /// finished mechanically (spec §10).
    var canAutoComplete: Bool {
        state.board.stock.isEmpty
            && state.board.tableau.allSatisfy { $0.allSatisfy(\.isFaceUp) }
            && greedySolution(from: state.board) != nil
    }

    /// The state as it stands right now, with `elapsed` brought up to date —
    /// what persistence writes. `state.elapsed` only advances when the clock is
    /// paused, so saving `state` directly would persist a stale timer.
    var snapshot: GameState {
        var copy = state
        copy.elapsed = elapsed
        return copy
    }

    // MARK: Intents (illegal intents are silent no-ops)

    /// Single-tap auto-move: send the run at `(column, index)` to its best legal
    /// destination (spec §7). Returns whether the board changed.
    @discardableResult
    func tap(column: Int, index: Int) -> Bool {
        guard let destination = Rules.autoMoveDestination(board: state.board, column: column, index: index)
        else { return false }
        let count = state.board.tableau[column].count - index
        return commit(.relocate(from: column, count: count, to: destination))
    }

    /// Explicit drag target: move the run starting at `(from, index)` onto `to`.
    @discardableResult
    func move(from: Int, index: Int, to: Int) -> Bool {
        guard state.board.tableau.indices.contains(from),
              index >= 0, index < state.board.tableau[from].count
        else { return false }
        let count = state.board.tableau[from].count - index
        return commit(.relocate(from: from, count: count, to: to))
    }

    @discardableResult
    func deal() -> Bool { commit(.deal) }

    /// Undo the last action: restore the previous board snapshot instantly and
    /// charge one undo (spec §9). No redo.
    @discardableResult
    func undo() -> Bool {
        guard let previous = state.undoStack.popLast() else { return false }
        state.board = previous
        state.undoCount += 1
        return true
    }

    /// Finish a mechanically-solvable board automatically, at no point cost
    /// (spec §10). Does nothing if not available.
    func autoComplete() {
        guard let moves = greedySolution(from: state.board) else { return }
        for move in moves { Rules.apply(move, to: &state.board) }  // no counter changes
        if isWon { pause() }
    }

    /// Replay the current deal from the beginning: the same cards, with score,
    /// counters, undo history, and timer all reset. Distinct from
    /// ``newGame(mode:rng:)``, which draws a *different* deal.
    func restart() {
        state = GameState(mode: state.mode, board: state.initialBoard)
        runningSince = nil
    }

    /// Start a new game, discarding the current one.
    func newGame(mode: SuitMode, rng: inout some RandomNumberGenerator) {
        state = GameState(mode: mode, board: dealProvider.makeDeal(mode: mode, using: &rng))
        runningSince = nil
    }

    // MARK: Timing

    func pause() {
        guard let since = runningSince else { return }
        state.elapsed += clock.now - since
        runningSince = nil
    }

    func resume() {
        guard state.timerStarted, !isWon, runningSince == nil else { return }
        runningSince = clock.now
    }

    // MARK: Internals

    /// Validate on a copy, then commit: snapshot the pre-action board for undo,
    /// apply, count the move, start the timer on the first move, freeze on a win.
    private func commit(_ move: Move) -> Bool {
        var board = state.board
        guard Rules.apply(move, to: &board) else { return false }
        state.undoStack.append(state.board)
        state.board = board
        state.moveCount += 1
        startTimerIfNeeded()
        if isWon { pause() }
        return true
    }

    private func startTimerIfNeeded() {
        guard !state.timerStarted else { return }
        state.timerStarted = true
        runningSince = clock.now
    }

    /// A bounded greedy finisher used by auto-complete: repeatedly plays the
    /// highest-priority legal auto-move until the game is won, or reports
    /// failure if it stalls or revisits a state.
    private func greedySolution(from board: Board) -> [Move]? {
        var current = board
        var moves: [Move] = []
        var seen: Set<Board> = [current]
        for _ in 0..<10_000 {
            if current.isWon { return moves }
            guard let move = bestGreedyMove(current) else { return nil }
            Rules.apply(move, to: &current)
            guard seen.insert(current).inserted else { return nil } // cycle
            moves.append(move)
        }
        return nil
    }

    /// Prefer moves that build same-suit sequences (which lead to clears);
    /// fall back to any legal auto-move. Empty-column targets are avoided to
    /// prevent trivial shuffling loops.
    private func bestGreedyMove(_ board: Board) -> Move? {
        var fallback: Move?
        for from in board.tableau.indices {
            let column = board.tableau[from]
            let runLength = Rules.topRunLength(column)
            guard runLength > 0 else { continue }
            let index = column.count - runLength
            guard let destination = Rules.autoMoveDestination(board: board, column: from, index: index)
            else { continue }
            let move = Move.relocate(from: from, count: runLength, to: destination)
            let destColumn = board.tableau[destination]
            if let destTop = destColumn.last, destTop.suit == column[index].suit {
                return move // same-suit continuation — take immediately
            }
            if !destColumn.isEmpty, fallback == nil { fallback = move }
        }
        return fallback
    }
}
