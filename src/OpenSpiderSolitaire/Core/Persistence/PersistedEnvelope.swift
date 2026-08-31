import Foundation

/// Wraps a payload with its schema version, so the version can be read
/// **before** the body is decoded — which is what lets migration run without
/// first failing a full decode (spec §5).
struct PersistedEnvelope<Body: Codable & Sendable>: Codable, Sendable {
    var schemaVersion: Int
    var body: Body
}

/// Just enough of an envelope to learn its version.
struct SchemaProbe: Codable, Sendable {
    let schemaVersion: Int
}

/// Why a payload could not be restored. Every case ends the same way — the
/// store is treated as absent (spec §8).
enum PersistenceFailure: Error, Equatable {
    /// Not JSON, or missing the envelope's version field.
    case unreadable
    /// Written by a newer build; a downgrade cannot be interpreted.
    case fromFuture(version: Int, current: Int)
    /// No contiguous chain of migrations reaches the current version.
    case noMigrationPath(from: Int, to: Int)
    /// A migration step threw.
    case migrationFailed(from: Int)
    /// Migrated or current JSON that still does not decode.
    case bodyDecodeFailed
}
