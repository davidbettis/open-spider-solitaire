import Foundation

/// Where ``SettingsStore`` keeps preferences between launches.
///
/// Implemented by ``PersistedSettingsStorage`` in the app and by an in-memory
/// double in tests, mirroring ``HighScoresStorage``.
protocol SettingsStorage {
    /// Returns `nil` when there is nothing stored, or nothing readable.
    func load() -> AppSettings?
    func save(_ settings: AppSettings)
}

/// Durable storage backed by the same atomically-replaced JSON file the high
/// scores use, since both live in ``DurableData``.
struct PersistedSettingsStorage: SettingsStorage {
    let persistence: PersistenceService

    func load() -> AppSettings? {
        persistence.loadDurableNow().settings
    }

    func save(_ settings: AppSettings) {
        // Read-modify-write for the same reason the high-scores path does it:
        // the two halves of DurableData must not clobber each other.
        var durable = persistence.loadDurableNow()
        durable.settings = settings
        persistence.saveDurableNow(durable)
    }
}
