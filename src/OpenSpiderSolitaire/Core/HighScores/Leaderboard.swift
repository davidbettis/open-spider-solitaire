import Foundation

/// A single mode's top-N table, kept sorted (spec §5). Pure value type: all
/// ranking lives here and is unit-tested without the store or any UI.
struct Leaderboard: Hashable, Codable, Sendable {
    /// Confirmed at 10 per the PRD recommendation (spec AI-1).
    static let maxEntries = 10

    private(set) var entries: [ScoreEntry]

    init(entries: [ScoreEntry] = []) {
        self.entries = Array(entries.sorted(by: Leaderboard.ranks).prefix(Leaderboard.maxEntries))
    }

    /// Strict weak ordering: score descending, then time ascending, then date
    /// ascending so equal results stay in the order they were achieved.
    ///
    /// A consequence the PRD accepts: because entries are coupled and ranked
    /// score-first, the all-time fastest time may not appear at all if a
    /// higher-scoring game was slower. That is intended.
    static func ranks(_ a: ScoreEntry, _ b: ScoreEntry) -> Bool {
        if a.score != b.score { return a.score > b.score }
        if a.time != b.time { return a.time < b.time }
        return a.date < b.date
    }

    /// The time on the current top entry — what a new game has to beat.
    var timeToBeat: TimeInterval? { entries.first?.time }

    /// Offer `entry` to the board, returning how it placed.
    @discardableResult
    mutating func insert(_ entry: ScoreEntry) -> Placement {
        let previousTop = entries.first

        var candidates = entries
        candidates.append(entry)
        candidates.sort(by: Leaderboard.ranks)
        entries = Array(candidates.prefix(Leaderboard.maxEntries))

        guard let index = entries.firstIndex(of: entry) else { return .missed }
        return Placement(
            madeLeaderboard: true,
            rank: index + 1,
            isNewBest: index == 0,
            // An empty board has no previous best, so nothing was beaten —
            // that case is reported by `isNewBest` alone.
            beatPreviousBestScore: previousTop.map { entry.score > $0.score } ?? false,
            beatPreviousBestTime: previousTop.map { entry.time < $0.time } ?? false
        )
    }
}
