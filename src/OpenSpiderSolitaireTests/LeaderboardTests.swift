import Foundation
import Testing
@testable import OpenSpiderSolitaire

/// Ranking and insertion are pure, so they are tested without the store
/// (spec §12).
@Suite("Leaderboard")
struct LeaderboardTests {

    @Test("Ranks by score descending")
    func ranksByScoreDescending() {
        var board = Leaderboard()
        board.insert(makeEntry(score: 400, time: 300))
        board.insert(makeEntry(score: 900, time: 999))
        board.insert(makeEntry(score: 650, time: 100))
        #expect(board.entries.map(\.score) == [900, 650, 400])
    }

    @Test("Equal scores break to the faster time")
    func tieBreaksOnTime() {
        var board = Leaderboard()
        board.insert(makeEntry(score: 500, time: 300))
        board.insert(makeEntry(score: 500, time: 120))
        board.insert(makeEntry(score: 500, time: 240))
        #expect(board.entries.map(\.time) == [120, 240, 300])
    }

    @Test("Equal score and time break to the earlier date")
    func tieBreaksOnDate() {
        var board = Leaderboard()
        board.insert(makeEntry(score: 500, time: 120, day: 5))
        board.insert(makeEntry(score: 500, time: 120, day: 1))
        #expect(board.entries.map(\.date) == [
            Date(timeIntervalSince1970: 86_400), Date(timeIntervalSince1970: 5 * 86_400),
        ])
    }

    @Test("The board never exceeds maxEntries and drops the weakest")
    func truncatesToMaxEntries() {
        var board = Leaderboard()
        for score in stride(from: 100, through: 1200, by: 100) {   // 12 entries
            board.insert(makeEntry(score: score, time: 100))
        }
        #expect(board.entries.count == Leaderboard.maxEntries)
        #expect(board.entries.first?.score == 1200)
        #expect(board.entries.last?.score == 300)                  // 100 and 200 dropped
    }

    @Test("An entry that misses the cut reports no placement")
    func missingTheCut() {
        var board = Leaderboard()
        for score in stride(from: 500, through: 1400, by: 100) {   // a full board
            board.insert(makeEntry(score: score, time: 100))
        }
        let placement = board.insert(makeEntry(score: 10, time: 100))
        #expect(!placement.madeLeaderboard)
        #expect(placement.rank == nil)
        #expect(board.entries.count == Leaderboard.maxEntries)
        #expect(!board.entries.contains { $0.score == 10 })
    }

    @Test("The first entry is a new best but beats no previous record")
    func firstEntryIsNewBest() {
        var board = Leaderboard()
        let placement = board.insert(makeEntry(score: 500, time: 200))
        #expect(placement.madeLeaderboard)
        #expect(placement.rank == 1)
        #expect(placement.isNewBest)
        // Nothing existed to beat — `isNewBest` alone reports this case.
        #expect(!placement.beatPreviousBestScore)
        #expect(!placement.beatPreviousBestTime)
    }

    @Test("Taking the top spot reports which previous records fell")
    func beatingThePreviousBest() {
        var board = Leaderboard()
        board.insert(makeEntry(score: 500, time: 200))
        let placement = board.insert(makeEntry(score: 700, time: 150))
        #expect(placement.isNewBest)
        #expect(placement.beatPreviousBestScore)
        #expect(placement.beatPreviousBestTime)
    }

    @Test("A higher but slower win beats the score record, not the time record")
    func higherScoreSlowerTime() {
        var board = Leaderboard()
        board.insert(makeEntry(score: 500, time: 100))
        let placement = board.insert(makeEntry(score: 700, time: 400))
        #expect(placement.isNewBest)
        #expect(placement.beatPreviousBestScore)
        #expect(!placement.beatPreviousBestTime)
        // The PRD accepts this: the all-time fastest time is now off the top.
        #expect(board.timeToBeat == 400)
    }

    @Test("Placing below the top is neither a new best nor a record")
    func midTablePlacement() {
        var board = Leaderboard()
        board.insert(makeEntry(score: 900, time: 100))
        let placement = board.insert(makeEntry(score: 400, time: 50))
        #expect(placement.madeLeaderboard)
        #expect(placement.rank == 2)
        #expect(!placement.isNewBest)
        #expect(!placement.beatPreviousBestScore)
        #expect(placement.beatPreviousBestTime)   // faster, just not higher
    }

    @Test("Time to beat is the top entry's time, nil when empty")
    func timeToBeat() {
        var board = Leaderboard()
        #expect(board.timeToBeat == nil)
        board.insert(makeEntry(score: 500, time: 275))
        #expect(board.timeToBeat == 275)
    }

    @Test("An over-long initial array is sorted and truncated")
    func initialiserNormalises() {
        let board = Leaderboard(entries: (1...15).map { makeEntry(score: $0 * 10, time: 100) })
        #expect(board.entries.count == Leaderboard.maxEntries)
        #expect(board.entries.first?.score == 150)
    }
}
