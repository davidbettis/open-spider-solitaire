import Foundation

/// The small, infrequently-written payload (spec §5): high scores today, and
/// where settings will live once a settings model exists — there is none yet,
/// so none is invented here.
struct DurableData: Hashable, Codable, Sendable {
    /// Version of *this* payload, independent of `GameState.schemaVersion`.
    static let currentSchemaVersion = 1

    var highScores: HighScoresData = HighScoresData()
}
