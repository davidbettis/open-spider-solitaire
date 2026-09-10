import Foundation

/// A leaderboard row to open the High Scores screen on and call out (spec §9).
///
/// Produced when a win lands on a mode's board. Leaving the won game hands one
/// of these back so the player is shown where they placed, rather than being
/// dropped on the title screen with the result already out of sight.
struct HighScoreHighlight: Hashable, Sendable {
    /// The board the row is on — also the mode the screen opens on.
    let mode: SuitMode
    /// The row itself, matched by value: score, time, and date together
    /// identify the one game that earned it.
    let entry: ScoreEntry
}
