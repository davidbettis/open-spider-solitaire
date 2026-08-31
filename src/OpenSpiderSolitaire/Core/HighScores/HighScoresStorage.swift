import Foundation

/// Where ``HighScoresStore`` keeps its data between launches.
///
/// Implemented by ``PersistedHighScoresStorage`` in the app and by an
/// in-memory double in tests.
protocol HighScoresStorage {
    /// Returns `nil` when there is nothing stored, or nothing readable.
    func load() -> HighScoresData?
    func save(_ data: HighScoresData)
}

/// Durable storage backed by the persistence layer's atomically-replaced JSON
/// file (persistence spec §4, resolving its AI-1 in favour of a file).
///
/// This replaced a `UserDefaults` implementation deliberately: `set` there is
/// asynchronous, so a win recorded moments before a hard kill could be lost.
/// An atomic file write has landed by the time `save` returns.
///
/// Reads and writes are synchronous because durable saves happen only on a win
/// or a reset — rare, and small enough to be sub-millisecond.
struct PersistedHighScoresStorage: HighScoresStorage {
    let persistence: PersistenceService

    func load() -> HighScoresData? {
        persistence.loadDurableNow().highScores
    }

    func save(_ data: HighScoresData) {
        // Read-modify-write, so settings can join the payload later without
        // this path clobbering them.
        var durable = persistence.loadDurableNow()
        durable.highScores = data
        persistence.saveDurableNow(durable)
    }
}
