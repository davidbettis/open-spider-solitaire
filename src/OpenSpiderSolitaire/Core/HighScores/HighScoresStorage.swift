import Foundation

/// Where ``HighScoresStore`` keeps its data between launches.
///
/// This is the seam [`persistence-and-migration`](../../../../docs/specs/persistence-and-migration.md)
/// will take over: that spec owns the envelope, the migration chain, and atomic
/// writes. Until it exists, the `UserDefaults` implementation below satisfies
/// the durable-store role the persistence spec assigns to small, infrequently
/// written payloads — and tests inject their own.
protocol HighScoresStorage {
    /// Returns `nil` when there is nothing stored, or nothing readable.
    func load() -> HighScoresData?
    func save(_ data: HighScoresData)
}

/// `UserDefaults`-backed durable store — the persistence spec's recommendation
/// for payloads this small.
struct UserDefaultsHighScoresStorage: HighScoresStorage {
    private static let key = "OpenSpiderSolitaire.highScores"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HighScoresData? {
        guard let raw = defaults.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode(HighScoresData.self, from: raw)
        else { return nil }
        // A payload from a newer build is unmigratable; fall back to defaults
        // rather than misreading it (persistence spec §7).
        guard decoded.schemaVersion <= HighScoresData.currentSchemaVersion else { return nil }
        return decoded
    }

    func save(_ data: HighScoresData) {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        defaults.set(raw, forKey: Self.key)
    }
}
