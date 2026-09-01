import Foundation

/// The small, infrequently-written payload (spec §5): high scores, and the
/// player's settings.
struct DurableData: Hashable, Codable, Sendable {
    /// Version of *this* payload, independent of `GameState.schemaVersion`.
    /// v2 added `settings`.
    static let currentSchemaVersion = 2

    var highScores: HighScoresData = HighScoresData()
    var settings: AppSettings = AppSettings()
}
