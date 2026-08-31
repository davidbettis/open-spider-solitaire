import Foundation

/// One winning game on a leaderboard. Score and time are **coupled** — they
/// come from the same game — so a row always shows the time that earned that
/// score (spec §4).
struct ScoreEntry: Hashable, Codable, Sendable {
    /// Floored at 0, consistent with the displayed score.
    let score: Int
    /// Elapsed time of that same winning game.
    let time: TimeInterval
    let date: Date
}

/// What happened when an entry was offered to a leaderboard — the raw material
/// for the win screen's "records beaten" line (spec §5).
struct Placement: Hashable, Codable, Sendable {
    /// Survived truncation to the top N.
    let madeLeaderboard: Bool
    /// 1-based rank, if it made the board.
    let rank: Int?
    /// Became rank 1 — a new top score for the mode.
    let isNewBest: Bool
    /// Scored higher than the previous top entry.
    let beatPreviousBestScore: Bool
    /// Finished faster than the previous top entry.
    let beatPreviousBestTime: Bool

    /// Nothing was recorded — used when a leaderboard rejects an entry.
    static let missed = Placement(madeLeaderboard: false, rank: nil, isNewBest: false,
                                  beatPreviousBestScore: false, beatPreviousBestTime: false)
}
