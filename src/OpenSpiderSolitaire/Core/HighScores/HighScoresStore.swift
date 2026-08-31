import Foundation
import Observation

/// Owns the leaderboards and stats the UI binds to, and writes through to the
/// durable store on every mutation (spec §10). All ranking lives in
/// ``Leaderboard``; this type is the observable shell around it.
@MainActor
@Observable
final class HighScoresStore {
    private(set) var data: HighScoresData

    @ObservationIgnored private let storage: any HighScoresStorage

    init(storage: any HighScoresStorage = UserDefaultsHighScoresStorage()) {
        self.storage = storage
        self.data = storage.load() ?? HighScoresData()
    }

    // MARK: Reads

    func leaderboard(_ mode: SuitMode) -> Leaderboard { data.leaderboards[mode] ?? Leaderboard() }
    func stats(_ mode: SuitMode) -> ModeStats { data.stats[mode] ?? ModeStats() }

    /// Time on the mode's current top entry, or `nil` while it is empty.
    func timeToBeat(_ mode: SuitMode) -> TimeInterval? { leaderboard(mode).timeToBeat }

    // MARK: Mutations (each persists immediately — these are small and rare)

    /// Count a game as started. Called once per game, when its first forward
    /// move lands.
    func recordGameStarted(mode: SuitMode) {
        var updated = stats(mode)
        updated.gamesStarted += 1
        data.stats[mode] = updated
        persist()
    }

    /// Record a win: bump the mode's counter, offer the result to its
    /// leaderboard, and hand back what the win screen should say.
    @discardableResult
    func recordWin(mode: SuitMode, score: Int, time: TimeInterval, date: Date = .now) -> WinSummary {
        // Defensive: only floored scores are ever stored (spec §2).
        let floored = max(0, score)

        var updatedStats = stats(mode)
        updatedStats.gamesWon += 1
        data.stats[mode] = updatedStats

        var board = leaderboard(mode)
        let placement = board.insert(ScoreEntry(score: floored, time: time, date: date))
        data.leaderboards[mode] = board

        persist()
        return WinSummary(flooredScore: floored, time: time,
                          placement: placement, newTimeToBeat: board.timeToBeat)
    }

    /// Clear every mode's leaderboard and stats. The UI gates this behind a
    /// confirmation (spec §8).
    func resetAll() {
        data = HighScoresData()
        persist()
    }

    private func persist() { storage.save(data) }
}
