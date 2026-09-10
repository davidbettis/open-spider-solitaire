import Foundation
import Testing
@testable import OpenSpiderSolitaire

/// The observable shell: per-mode isolation, stats accounting, persistence
/// write-through, and reset (spec §12).
@MainActor
@Suite("HighScoresStore")
struct HighScoresStoreTests {

    private func store() -> (HighScoresStore, InMemoryHighScoresStorage) {
        let storage = InMemoryHighScoresStorage()
        return (HighScoresStore(storage: storage), storage)
    }

    @Test("Leaderboards are per mode; one never affects another")
    func modesAreIsolated() {
        let (store, _) = store()
        store.recordWin(mode: .one, score: 900, time: 100)
        store.recordWin(mode: .four, score: 300, time: 500)

        #expect(store.leaderboard(.one).entries.map(\.score) == [900])
        #expect(store.leaderboard(.four).entries.map(\.score) == [300])
        #expect(store.leaderboard(.two).entries.isEmpty)
        #expect(store.timeToBeat(.one) == 100)
        #expect(store.timeToBeat(.two) == nil)
    }

    @Test("A win couples the score with that same game's time")
    func scoreAndTimeAreCoupled() {
        let (store, _) = store()
        let summary = store.recordWin(mode: .two, score: 640, time: 372)
        #expect(summary.flooredScore == 640)
        #expect(summary.time == 372)
        let entry = store.leaderboard(.two).entries.first
        #expect(entry?.score == 640)
        #expect(entry?.time == 372)
    }

    @Test("Negative scores are floored to zero before storing")
    func scoresAreFloored() {
        let (store, _) = store()
        let summary = store.recordWin(mode: .one, score: -50, time: 200)
        #expect(summary.flooredScore == 0)
        #expect(store.leaderboard(.one).entries.first?.score == 0)
    }

    @Test("A win that makes the board carries the row it left there")
    func summaryCarriesTheRecordedRow() {
        let (store, _) = store()
        let date = Date(timeIntervalSince1970: 1_000)
        let summary = store.recordWin(mode: .two, score: 640, time: 372, date: date)

        #expect(summary.placement.madeLeaderboard)
        #expect(summary.recordedEntry == ScoreEntry(score: 640, time: 372, date: date))
        // The very row that is on the board, so the screen can match it by value.
        #expect(store.leaderboard(.two).entries.first == summary.recordedEntry)
    }

    @Test("The recorded row carries the floored score, not the raw one")
    func recordedRowIsFloored() {
        let (store, _) = store()
        let summary = store.recordWin(mode: .one, score: -50, time: 200)
        #expect(summary.recordedEntry?.score == 0)
    }

    @Test("A finish that misses the top ten carries no row")
    func summaryOmitsRowWhenBoardIsMissed() {
        let (store, _) = store()
        for _ in 0..<Leaderboard.maxEntries {
            store.recordWin(mode: .one, score: 900, time: 100)
        }
        let summary = store.recordWin(mode: .one, score: 10, time: 999)

        #expect(!summary.placement.madeLeaderboard)
        #expect(summary.recordedEntry == nil)
        #expect(store.leaderboard(.one).entries.count == Leaderboard.maxEntries)
    }

    @Test("The summary reports the time to beat after this game")
    func summaryCarriesNewTimeToBeat() {
        let (store, _) = store()
        store.recordWin(mode: .one, score: 500, time: 300)
        let summary = store.recordWin(mode: .one, score: 800, time: 220)
        #expect(summary.placement.isNewBest)
        #expect(summary.newTimeToBeat == 220)
        #expect(store.timeToBeat(.one) == 220)
    }

    @Test("Games started and won are counted per mode")
    func statsCounting() {
        let (store, _) = store()
        store.recordGameStarted(mode: .one)
        store.recordGameStarted(mode: .one)
        store.recordGameStarted(mode: .four)
        store.recordWin(mode: .one, score: 500, time: 100)

        #expect(store.stats(.one).gamesStarted == 2)
        #expect(store.stats(.one).gamesWon == 1)
        #expect(store.stats(.one).winRate == 0.5)
        #expect(store.stats(.four).gamesStarted == 1)
        #expect(store.stats(.four).gamesWon == 0)
    }

    @Test("Win rate is zero with no games started, never a divide by zero")
    func winRateWithNoGames() {
        let (store, _) = store()
        #expect(store.stats(.two).gamesStarted == 0)
        #expect(store.stats(.two).winRate == 0)
    }

    @Test("Reset clears every mode's leaderboard and stats, and persists")
    func resetClearsEverything() {
        let (store, storage) = store()
        store.recordGameStarted(mode: .one)
        store.recordWin(mode: .one, score: 500, time: 100)
        store.recordWin(mode: .four, score: 700, time: 200)

        store.resetAll()

        for mode in SuitMode.allCases {
            #expect(store.leaderboard(mode).entries.isEmpty)
            #expect(store.stats(mode).gamesStarted == 0)
            #expect(store.stats(mode).gamesWon == 0)
        }
        #expect(storage.stored?.leaderboards.isEmpty == true)
    }

    @Test("Every mutation writes through to the durable store")
    func mutationsPersist() {
        let (store, storage) = store()
        #expect(storage.saveCount == 0)
        store.recordGameStarted(mode: .one)
        #expect(storage.saveCount == 1)
        store.recordWin(mode: .one, score: 400, time: 100)
        #expect(storage.saveCount == 2)
        #expect(storage.stored?.leaderboards[.one]?.entries.count == 1)
    }

    @Test("A new store reads back what the previous one saved")
    func dataSurvivesRelaunch() {
        let storage = InMemoryHighScoresStorage()
        let first = HighScoresStore(storage: storage)
        first.recordGameStarted(mode: .two)
        first.recordWin(mode: .two, score: 815, time: 244)

        let second = HighScoresStore(storage: storage)
        #expect(second.leaderboard(.two).entries.first?.score == 815)
        #expect(second.timeToBeat(.two) == 244)
        #expect(second.stats(.two).gamesWon == 1)
    }

    @Test("HighScoresData round-trips through Codable with mode-keyed JSON")
    func codableRoundTrip() throws {
        var data = HighScoresData()
        data.leaderboards[.four] = Leaderboard(entries: [makeEntry(score: 700, time: 250, day: 3)])
        data.stats[.four] = ModeStats(gamesStarted: 4, gamesWon: 1)

        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(HighScoresData.self, from: encoded)
        #expect(decoded == data)

        // Modes key the JSON objects, rather than degrading to a flat array.
        let json = try #require(String(data: encoded, encoding: .utf8))
        #expect(json.contains("\"4\""))
    }
}
