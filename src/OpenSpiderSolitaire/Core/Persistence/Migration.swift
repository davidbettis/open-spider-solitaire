import Foundation

/// One structural upgrade, `from` → `to` (always `from + 1`), applied to the
/// **raw JSON** of a whole envelope. Working on JSON rather than typed models
/// means retired shapes never have to stay compilable as Swift types (spec §7).
protocol Migration: Sendable {
    var from: Int { get }
    var to: Int { get }
    func migrate(_ json: Data) throws -> Data
}

/// An ordered set of migrations, applied stepwise to bring an old payload up
/// to the current version.
struct MigrationChain: Sendable {
    let migrations: [any Migration]

    init(_ migrations: [any Migration] = []) {
        self.migrations = migrations.sorted { $0.from < $1.from }
    }

    /// Walk `from` up to `current`, one contiguous step at a time.
    func upgrade(_ data: Data, from: Int, to current: Int) throws -> Data {
        guard from <= current else {
            throw PersistenceFailure.fromFuture(version: from, current: current)
        }
        var json = data
        var version = from
        while version < current {
            guard let step = migrations.first(where: { $0.from == version }) else {
                throw PersistenceFailure.noMigrationPath(from: version, to: current)
            }
            do {
                json = try step.migrate(json)
            } catch {
                throw PersistenceFailure.migrationFailed(from: version)
            }
            version = step.to
        }
        return json
    }
}

/// `GameState` v1 → v2: v2 added `initialBoard` so Restart can replay the
/// current deal. A v1 save has no such field, and the best available answer is
/// the board as saved — restarting an old save returns to where it was picked
/// up rather than to a deal that was never recorded.
struct GameStateV1ToV2: Migration {
    let from = 1
    let to = 2

    func migrate(_ json: Data) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: json) as? [String: Any],
              var body = root["body"] as? [String: Any]
        else { throw PersistenceFailure.unreadable }

        if body["initialBoard"] == nil {
            guard let board = body["board"] else { throw PersistenceFailure.unreadable }
            body["initialBoard"] = board
        }
        body["schemaVersion"] = 2
        root["body"] = body
        root["schemaVersion"] = 2
        return try JSONSerialization.data(withJSONObject: root)
    }
}

/// `DurableData` v1 → v2: v2 added `settings`, which v1 payloads predate.
/// The defaults are what the app already behaved like before the settings
/// existed - 1-suit difficulty and the system appearance - so an existing
/// player notices nothing, and crucially keeps their high scores. Without
/// this step a v1 file would fail to upgrade and reset to defaults.
struct DurableDataV1ToV2: Migration {
    let from = 1
    let to = 2

    func migrate(_ json: Data) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: json) as? [String: Any],
              var body = root["body"] as? [String: Any]
        else { throw PersistenceFailure.unreadable }

        if body["settings"] == nil {
            body["settings"] = ["suitMode": SuitMode.one.rawValue,
                                "appearance": Appearance.system.rawValue]
        }
        root["body"] = body
        // DurableData carries no schemaVersion of its own; the envelope is the
        // single authority (see HighScoresData's note).
        root["schemaVersion"] = 2
        return try JSONSerialization.data(withJSONObject: root)
    }
}
