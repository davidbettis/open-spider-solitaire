import Foundation
import Testing
@testable import OpenSpiderSolitaire

/// Round-trip, migration, and the graceful-failure paths (spec §11/§12).
/// Every case writes to a unique temp file, so tests never share state.
@Suite("Persistence")
struct PersistenceTests {

    private func tempStore(_ name: String = UUID().uuidString) -> JSONFileStore {
        JSONFileStore(url: URL.temporaryDirectory.appending(path: "\(name).json"))
    }

    private func service(game: JSONFileStore, durable: JSONFileStore) -> PersistenceService {
        PersistenceService(game: game, durable: durable,
                           gameMigrations: MigrationChain([GameStateV1ToV2()]))
    }

    /// A mid-game state: moves made, undo history, and a running clock.
    private func midGameState() -> GameState {
        var rng = SplitMix64(seed: 11)
        var board = RandomDealProvider().makeDeal(mode: .two, using: &rng)
        let snapshot = board
        board.stock.removeLast(10)
        return GameState(mode: .two, board: board, initialBoard: snapshot,
                         moveCount: 7, undoCount: 2, elapsed: 412.5,
                         timerStarted: true, undoStack: [snapshot, snapshot])
    }

    // MARK: Round trip

    @Test("A mid-game state survives save and load unchanged")
    func gameRoundTrips() {
        let game = tempStore(), durable = tempStore()
        defer { game.delete(); durable.delete() }
        let service = service(game: game, durable: durable)
        let original = midGameState()

        service.saveGameSynchronously(original)
        let loaded = try? #require(service.loadGameNow())

        #expect(loaded?.board == original.board)
        #expect(loaded?.initialBoard == original.initialBoard)
        #expect(loaded?.undoStack == original.undoStack)
        #expect(loaded?.moveCount == original.moveCount)
        #expect(loaded?.undoCount == original.undoCount)
        #expect(loaded?.elapsed == original.elapsed)
        #expect(loaded?.timerStarted == original.timerStarted)
        #expect(loaded?.mode == original.mode)
    }

    @Test("No saved game reads as nil, not as a failure")
    func absentGameIsNil() {
        let game = tempStore(), durable = tempStore()
        #expect(service(game: game, durable: durable).loadGameNow() == nil)
    }

    @Test("Deleting the snapshot makes the next launch start fresh")
    func deleteRemovesTheSnapshot() async {
        let game = tempStore(), durable = tempStore()
        defer { game.delete(); durable.delete() }
        let service = service(game: game, durable: durable)

        service.saveGameSynchronously(midGameState())
        #expect(game.exists)
        await service.deleteGame()
        #expect(!game.exists)
        #expect(service.loadGameNow() == nil)
    }

    @Test("A v1 durable payload keeps its high scores and gains default settings")
    func durableV1Migrates() throws {
        let game = tempStore(), durable = tempStore()
        defer { game.delete(); durable.delete() }

        // A v1 payload: high scores, and no settings key at all.
        var scores = HighScoresData()
        scores.leaderboards[.two] = Leaderboard(entries: [makeEntry(score: 777, time: 123)])

        let v1: [String: Any] = [
            "schemaVersion": 1,
            "body": ["highScores": try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(scores))]
        ]
        durable.write(try JSONSerialization.data(withJSONObject: v1))

        // Without the migration this fails to upgrade and resets to defaults,
        // losing the player's scores - the regression this guards.
        let loaded = service(game: game, durable: durable).loadDurableNow()
        #expect(loaded.highScores.leaderboards[.two]?.entries.first?.score == 777)
        #expect(loaded.settings == AppSettings())
        #expect(loaded.settings.suitMode == .one)
    }

    @Test("Durable data round-trips and defaults when absent")
    func durableRoundTrips() {
        let game = tempStore(), durable = tempStore()
        defer { game.delete(); durable.delete() }
        let service = service(game: game, durable: durable)

        #expect(service.loadDurableNow() == DurableData())   // nothing stored yet

        var data = DurableData()
        data.highScores.leaderboards[.one] = Leaderboard(entries: [makeEntry(score: 900, time: 120)])
        data.highScores.stats[.one] = ModeStats(gamesStarted: 3, gamesWon: 1)
        service.saveDurableNow(data)

        #expect(service.loadDurableNow() == data)
    }

    // MARK: Migration

    /// A v1 envelope: `GameState` before `initialBoard` existed.
    private func v1GameJSON() throws -> Data {
        var rng = SplitMix64(seed: 3)
        let board = RandomDealProvider().makeDeal(mode: .one, using: &rng)
        let current = GameState(mode: .one, board: board, moveCount: 4, elapsed: 90, timerStarted: true)
        let encoded = try JSONEncoder().encode(
            PersistedEnvelope(schemaVersion: 2, body: current))
        var root = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var body = try #require(root["body"] as? [String: Any])
        body.removeValue(forKey: "initialBoard")      // the v1 shape
        body["schemaVersion"] = 1
        root["body"] = body
        root["schemaVersion"] = 1
        return try JSONSerialization.data(withJSONObject: root)
    }

    @Test("A v1 save migrates to v2 and decodes, with initialBoard filled in")
    func migratesV1ToV2() throws {
        let game = tempStore(), durable = tempStore()
        defer { game.delete(); durable.delete() }
        game.write(try v1GameJSON())

        let loaded = try #require(service(game: game, durable: durable).loadGameNow())
        #expect(loaded.moveCount == 4)
        #expect(loaded.elapsed == 90)
        // v1 recorded no original deal, so the board as saved is the best answer.
        #expect(loaded.initialBoard == loaded.board)
    }

    @Test("A chain with no step for the stored version refuses to guess")
    func missingMigrationStep() throws {
        let chain = MigrationChain()      // no migrations at all
        #expect(throws: PersistenceFailure.noMigrationPath(from: 1, to: 2)) {
            try chain.upgrade(Data(), from: 1, to: 2)
        }
    }

    @Test("A migration that throws is reported as a failed step")
    func throwingMigration() {
        struct Exploding: Migration {
            let from = 1, to = 2
            func migrate(_ json: Data) throws -> Data { throw PersistenceFailure.unreadable }
        }
        #expect(throws: PersistenceFailure.migrationFailed(from: 1)) {
            try MigrationChain([Exploding()]).upgrade(Data(), from: 1, to: 2)
        }
    }

    // MARK: Graceful failure (spec §8)

    @Test("Truncated JSON is discarded and the snapshot deleted")
    func truncatedFileIsDiscarded() {
        let game = tempStore(), durable = tempStore()
        defer { game.delete(); durable.delete() }
        game.write(Data(#"{"schemaVersion":2,"body":{"mod"#.utf8))

        #expect(service(game: game, durable: durable).loadGameNow() == nil)
        #expect(!game.exists)   // cleaned up, so it cannot fail again next launch
    }

    @Test("A save from a newer build is discarded rather than misread")
    func newerVersionIsDiscarded() throws {
        let game = tempStore(), durable = tempStore()
        defer { game.delete(); durable.delete() }
        let envelope = PersistedEnvelope(schemaVersion: GameState.currentSchemaVersion + 5,
                                         body: midGameState())
        game.write(try JSONEncoder().encode(envelope))

        #expect(service(game: game, durable: durable).loadGameNow() == nil)
        #expect(!game.exists)
    }

    @Test("Well-formed JSON of the wrong shape is discarded")
    func wrongShapeIsDiscarded() {
        let game = tempStore(), durable = tempStore()
        defer { game.delete(); durable.delete() }
        game.write(Data(#"{"schemaVersion":2,"body":{"mode":"nonsense"}}"#.utf8))

        #expect(service(game: game, durable: durable).loadGameNow() == nil)
    }

    @Test("Corrupt durable data falls back to defaults instead of failing")
    func corruptDurableResetsToDefaults() {
        let game = tempStore(), durable = tempStore()
        defer { game.delete(); durable.delete() }
        durable.write(Data("not json at all".utf8))

        #expect(service(game: game, durable: durable).loadDurableNow() == DurableData())
    }

    // MARK: Atomicity (spec §6.4)

    @Test("A stray temp file never replaces the good save")
    func priorSaveSurvivesAnInterruptedWrite() throws {
        let game = tempStore(), durable = tempStore()
        defer { game.delete(); durable.delete() }
        let service = service(game: game, durable: durable)

        service.saveGameSynchronously(midGameState())
        let good = try #require(game.read())

        // Simulate a write that died before its atomic replace: a sibling temp
        // file exists, and the target is untouched.
        let temp = game.url.deletingLastPathComponent().appending(path: "game.json.tmp")
        try Data("half-written".utf8).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        #expect(game.read() == good)
        #expect(service.loadGameNow()?.moveCount == 7)
    }

    // MARK: Autosave coalescing (spec §6.1)

    @Test("A burst of autosaves coalesces into one write")
    func autosaveDebounces() async throws {
        let game = tempStore(), durable = tempStore()
        defer { game.delete(); durable.delete() }
        let service = service(game: game, durable: durable)

        for _ in 0..<5 { await service.scheduleGameSave(midGameState()) }
        #expect(!game.exists)      // nothing written yet — still coalescing

        try await Task.sleep(for: PersistenceService.autosaveDebounce + .milliseconds(400))
        #expect(game.exists)
        #expect(service.loadGameNow()?.moveCount == 7)
    }

    @Test("An immediate save cancels a pending autosave")
    func immediateSaveSupersedesPending() async throws {
        let game = tempStore(), durable = tempStore()
        defer { game.delete(); durable.delete() }
        let service = service(game: game, durable: durable)

        var state = midGameState()
        await service.scheduleGameSave(state)
        state.moveCount = 99
        await service.saveGameNow(state)

        #expect(service.loadGameNow()?.moveCount == 99)
        try await Task.sleep(for: PersistenceService.autosaveDebounce + .milliseconds(400))
        #expect(service.loadGameNow()?.moveCount == 99)   // the stale save never lands
    }
}
