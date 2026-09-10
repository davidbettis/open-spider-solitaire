import Foundation

/// Per-mode counters. `gamesStarted` counts a game once its first forward move
/// lands (the engine's `timerStarted` flip), so an abandoned game still counts
/// toward the denominator and the win rate stays meaningful (spec §6, AI-2).
struct ModeStats: Hashable, Codable, Sendable {
    var gamesStarted: Int = 0
    var gamesWon: Int = 0

    /// Derived, never stored. Zero games started reads as a zero rate rather
    /// than dividing by zero.
    var winRate: Double {
        gamesStarted == 0 ? 0 : Double(gamesWon) / Double(gamesStarted)
    }
}

/// Everything High Scores owns, as one persistable value (spec §4).
///
/// Versioning lives on the envelope that wraps ``DurableData``, not here, so
/// there is exactly one version to reason about per stored payload.
struct HighScoresData: Hashable, Codable, Sendable {
    var leaderboards: [SuitMode: Leaderboard] = [:]
    var stats: [SuitMode: ModeStats] = [:]
}

/// Keys the mode dictionaries as `"1"` / `"2"` / `"4"` instead of a flat
/// key/value array, so the stored JSON stays readable and diffable.
extension SuitMode: CodingKeyRepresentable {}

/// What the win screen needs: the numbers, and which records fell (spec §7).
struct WinSummary: Hashable, Sendable {
    let flooredScore: Int
    let time: TimeInterval
    let placement: Placement
    /// The time to beat *after* this game was recorded.
    let newTimeToBeat: TimeInterval?
    /// The row this win left on the leaderboard, or `nil` if it missed the top
    /// N. Carried so the win screen can send the player to that exact row
    /// rather than to the title screen (spec §9).
    let recordedEntry: ScoreEntry?
}
