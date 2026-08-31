import Foundation

/// Owns all save/load for the app (spec §9).
///
/// **Where the work happens.** The frequent path — autosaving the in-progress
/// game after every board change — is debounced and runs inside the actor, off
/// the main thread. The two rare paths deliberately run synchronously instead:
/// loading once at launch (so the UI never flashes a menu before resuming) and
/// the save on the way to the background (so it cannot lose a race with
/// termination). Both write well under a millisecond for payloads this size.
actor PersistenceService {
    /// Coalescing window for autosave, so rapid play does not thrash the disk
    /// (spec §6.1, AI-2).
    static let autosaveDebounce: Duration = .milliseconds(500)

    private let game: JSONFileStore
    private let durable: JSONFileStore
    private let gameMigrations: MigrationChain

    private var pendingSave: Task<Void, Never>?

    init(game: JSONFileStore = .inApplicationSupport("game.json"),
         durable: JSONFileStore = .inApplicationSupport("durable.json"),
         gameMigrations: MigrationChain = MigrationChain([GameStateV1ToV2()])) {
        self.game = game
        self.durable = durable
        self.gameMigrations = gameMigrations
    }

    // MARK: In-progress game

    /// Autosave, coalesced: a burst of moves writes once.
    func scheduleGameSave(_ state: GameState) {
        pendingSave?.cancel()
        pendingSave = Task { [game] in
            try? await Task.sleep(for: PersistenceService.autosaveDebounce)
            guard !Task.isCancelled else { return }
            PersistenceService.writeGame(state, to: game)
        }
    }

    /// Write now, cancelling any pending autosave.
    func saveGameNow(_ state: GameState) {
        pendingSave?.cancel()
        pendingSave = nil
        PersistenceService.writeGame(state, to: game)
    }

    /// Drop the snapshot — the game it described is over (spec §6.1).
    func deleteGame() {
        pendingSave?.cancel()
        pendingSave = nil
        game.delete()
    }

    // MARK: Synchronous paths (see the type's note)

    /// Load the resumable game, or `nil` if there is none. Anything unreadable,
    /// unmigratable, or from a newer build is deleted and reported as absent
    /// (spec §8).
    nonisolated func loadGameNow() -> GameState? {
        do {
            return try PersistenceService.decode(
                GameState.self, from: game, current: GameState.currentSchemaVersion,
                migrations: gameMigrations)
        } catch {
            game.delete()
            return nil
        }
    }

    /// Save on the way out — see the type's note on why this is synchronous.
    nonisolated func saveGameSynchronously(_ state: GameState) {
        PersistenceService.writeGame(state, to: game)
    }

    /// Durable data never throws: a failure resets to defaults (spec §9).
    nonisolated func loadDurableNow() -> DurableData {
        (try? PersistenceService.decode(
            DurableData.self, from: durable, current: DurableData.currentSchemaVersion,
            migrations: MigrationChain())) ?? DurableData()
    }

    /// Durable writes are small and rare, so they land immediately rather than
    /// racing termination (spec §6.2).
    nonisolated func saveDurableNow(_ data: DurableData) {
        let envelope = PersistedEnvelope(schemaVersion: DurableData.currentSchemaVersion, body: data)
        guard let encoded = try? JSONEncoder().encode(envelope) else { return }
        durable.write(encoded)
    }

    // MARK: Internals

    private static func writeGame(_ state: GameState, to store: JSONFileStore) {
        let envelope = PersistedEnvelope(schemaVersion: GameState.currentSchemaVersion, body: state)
        guard let encoded = try? JSONEncoder().encode(envelope) else { return }
        store.write(encoded)
    }

    /// Read the version, migrate if it is behind, then decode the body.
    private static func decode<Body: Codable & Sendable>(
        _ type: Body.Type, from store: JSONFileStore, current: Int, migrations: MigrationChain
    ) throws -> Body? {
        guard let raw = store.read() else { return nil }   // nothing saved is not a failure
        guard let probe = try? JSONDecoder().decode(SchemaProbe.self, from: raw) else {
            throw PersistenceFailure.unreadable
        }
        guard probe.schemaVersion <= current else {
            throw PersistenceFailure.fromFuture(version: probe.schemaVersion, current: current)
        }

        let upgraded = probe.schemaVersion == current
            ? raw
            : try migrations.upgrade(raw, from: probe.schemaVersion, to: current)

        guard let envelope = try? JSONDecoder().decode(PersistedEnvelope<Body>.self, from: upgraded) else {
            throw PersistenceFailure.bodyDecodeFailed
        }
        return envelope.body
    }
}
