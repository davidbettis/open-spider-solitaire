import Foundation

/// The derived scoring model, per `docs/specs/game-engine.md` §8.
///
/// Score is a pure function of the monotonic counters and the current board —
/// never accumulated — which makes point-farming structurally impossible and
/// undo trivially correct.
enum Scoring {
    static let startingScore = 500

    /// May be negative; use ``displayScore(for:)`` for anything user-facing or
    /// saved to a leaderboard.
    static func internalScore(for state: GameState) -> Int {
        startingScore
            - state.moveCount
            - state.undoCount
            + 100 * state.board.completedRuns.count
    }

    /// Floored at 0, for display and leaderboard storage.
    static func displayScore(for state: GameState) -> Int {
        max(0, internalScore(for: state))
    }
}
