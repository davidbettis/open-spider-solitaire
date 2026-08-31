# Feature Spec: High Scores & Stats

- **Status:** Implemented. Durability currently rides on `UserDefaults`; [`persistence-and-migration`](./persistence-and-migration.md) will take over the store (see §10).
- **Owner:** TBD
- **Source PRD:** [`docs/PRD.md`](../PRD.md)
- **Spec sequence:** #4. Depends on [`game-engine`](./game-engine.md) (final score/time) and [`persistence-and-migration`](./persistence-and-migration.md) (storage).
- **Target:** Swift 6, iOS 17+.

---

## 1. Summary

High Scores maintains a **per-suit-mode top-N leaderboard** of completed games, where each entry couples the winning game's **score and time**, ranked score-first then time. It also tracks optional stats (games won, win rate) and supports a confirmed reset. It provides the data for the High Scores screen and the Win screen's "records beaten" summary. It defines the leaderboard/stats models; storage and versioning are executed by [`persistence-and-migration`](./persistence-and-migration.md).

## 2. Goals / Non-Goals

**Goals**
- Separate top-N leaderboards per mode (recommend **N = 10**).
- Coupled `{score, time}` entries; rank score desc, then time asc.
- Expose **time-to-beat** = time on the current top entry for a mode.
- Track per-mode stats: games won, games started, win rate.
- Reset all high scores (and stats) behind a confirmation.
- Save only **floored (≥0)** scores, consistent with display.

**Non-Goals**
- On-disk format/migration — [`persistence-and-migration`](./persistence-and-migration.md).
- Score computation — [`game-engine`](./game-engine.md) supplies the final floored score and elapsed.
- Global/online leaderboards, accounts, sharing (PRD: offline, no accounts).
- Win-screen animation — [`animations`](./animations.md); this spec supplies the summary *data*.

## 3. User Stories

- **US-1** — As a player, when I win, my score and time are recorded on that mode's leaderboard if they rank in the top 10.
- **US-2** — As a player, I can view the top 10 for each mode, each row showing score and the time from that same game.
- **US-3** — As a player, I can see the current "time to beat" for a mode.
- **US-4** — As a player, the win screen tells me which records I beat this game.
- **US-5** — As a player, I can reset all high scores, after confirming.
- **US-6** — As a player, I can see how many games I've won and my win rate per mode.

## 4. Data Model

```swift
struct ScoreEntry: Hashable, Codable, Sendable {
    let score: Int              // floored, ≥ 0
    let time: TimeInterval      // elapsed of the same winning game
    let date: Date              // when achieved
}

struct Leaderboard: Codable, Sendable {
    static let maxEntries = 10
    private(set) var entries: [ScoreEntry]   // kept sorted, length ≤ maxEntries
}

struct ModeStats: Codable, Sendable {
    var gamesStarted: Int       // ++ when a game's first move is made (timer starts)
    var gamesWon: Int           // ++ on win
    var winRate: Double { gamesStarted == 0 ? 0 : Double(gamesWon) / Double(gamesStarted) }
}

/// Owned here; persisted by the durable store.
struct HighScoresData: Codable, Sendable {
    var leaderboards: [SuitMode: Leaderboard]
    var stats: [SuitMode: ModeStats]
}
```

## 5. Ranking & Insertion

**Ordering** (strict weak order):
1. `score` **descending** (higher is better).
2. `time` **ascending** (faster breaks ties).
3. `date` ascending as a final deterministic tie-break (earlier achievement ranks first).

**Insertion** (`insert(_ entry:) -> Placement`):
- Append `entry`, sort by the ordering, truncate to `maxEntries`.
- Return a `Placement` describing outcome for the win summary:
  ```swift
  struct Placement {
      let madeLeaderboard: Bool     // survived truncation
      let rank: Int?                // 1-based, if on the board
      let isNewBest: Bool           // became rank 1 (new time-to-beat / top score)
      let beatPreviousBestScore: Bool
      let beatPreviousBestTime: Bool // faster than the prior top entry's time
  }
  ```

**Time-to-beat** for a mode = `leaderboard.entries.first?.time` (nil if empty).

> Accepted consequence (PRD): because entries are coupled and ranked score-then-time, the all-time fastest time may not appear if a higher-scoring game was slower. This is intended, not a bug.

## 6. Stats Accounting

- `gamesStarted` increments once per game when the **first forward move** is made (aligns with the engine's `timerStarted` flip) — a started-and-abandoned game counts toward the denominator so win rate is meaningful.
- `gamesWon` increments on a win, alongside the leaderboard insert.
- `winRate` is derived, not stored.
- Reset clears leaderboards **and** stats for all modes.

## 7. Win-Screen Summary Data

On a win, the engine/session provides `(mode, flooredScore, elapsed)`. This module:
1. Increments `gamesWon[mode]`.
2. Inserts a `ScoreEntry(score, time, date: .now)` → `Placement`.
3. Returns a `WinSummary { flooredScore, time, placement, newTimeToBeat }` for the Win screen ([`animations`](./animations.md) renders the cascade; this supplies the numbers and "records beaten" flags).

## 8. Reset

- `resetAll()` clears every mode's leaderboard and stats to empty/zero and persists.
- The UI gates this behind a confirmation dialog (destructive style); only on confirm is `resetAll()` called.

## 9. Screens

- **High Scores screen:** a segmented control or list sectioned by mode; each section shows the mode's top-N rows (`rank · score · time · date`), the current time-to-beat, and stats (games won, win rate). Empty modes show a friendly empty state.
- **Win screen summary region:** final score, final time, and which records were beaten (from `Placement`).

## 10. Architecture & Concurrency

- `@MainActor @Observable final class HighScoresStore` holds `HighScoresData`, exposes read models to views, and writes through to a `HighScoresStorage` on every mutation. That protocol is the seam the persistence spec will implement properly; today it is backed by `UserDefaults`, which that spec nominates for small, infrequently written payloads. Tests inject an in-memory double.
  ```swift
  @MainActor @Observable
  final class HighScoresStore {
      func timeToBeat(_ mode: SuitMode) -> TimeInterval?
      func recordWin(mode: SuitMode, score: Int, time: TimeInterval) -> WinSummary
      func recordGameStarted(mode: SuitMode)
      func resetAll()
      func leaderboard(_ mode: SuitMode) -> Leaderboard
      func stats(_ mode: SuitMode) -> ModeStats
  }
  ```
- All models are `Sendable` value types; ranking/insertion are pure and unit-tested independently of the store.

## 11. Acceptance Criteria

- [x] Leaderboards are tracked separately per mode; an entry in one mode never affects another.
- [x] Entries couple score+time from the same game; the displayed time is that game's time.
- [x] Ranking is score desc, then time asc, then date asc; verified with tie fixtures.
- [x] A leaderboard never exceeds `maxEntries`; the lowest-ranked entry is dropped on overflow.
- [x] Only floored (≥0) scores are stored.
- [x] `timeToBeat` returns the top entry's time (nil when empty).
- [x] `Placement` correctly reports `madeLeaderboard`, `rank`, `isNewBest`, and beat-previous-best flags across representative wins.
- [x] `gamesStarted` increments once per started game; `gamesWon` on each win; `winRate` computes correctly, and 0 started ⇒ 0 rate (no divide-by-zero).
- [x] `resetAll()` clears leaderboards and stats for all modes and persists; only fires after confirmation.
- [x] Data survives app restart — verified in the simulator by reading a leaderboard written by an earlier process. **Caveat:** `UserDefaults.set` is asynchronous, so a win recorded moments before a hard kill can be lost. The persistence spec's atomic write plus its save-on-`.background` trigger (§6.2/§6.4) is the fix; until then this is a known, narrow gap.

## 12. Testing Strategy

- Pure ranking/insertion tests: ordering, tie-breaks, truncation, `Placement` correctness.
- Stats tests: started/won counting, win-rate edge cases (0 started).
- Store tests with an in-memory persistence double.
- Round-trip of `HighScoresData` through `Codable` (persistence spec owns migration).

## 13. Open Questions / Action Items

- ~~**AI-1:** Confirm N = 10~~ — **resolved**: `Leaderboard.maxEntries = 10`.
- ~~**AI-2:** Should `gamesStarted` count games abandoned before the first move?~~ — **resolved**: no. It increments on the engine's `timerStarted` flip, so a game abandoned before its first move counts for nothing, and one abandoned after counts toward the denominator.
- ~~**AI-3:** Display formatting for time~~ — **resolved**: both screens use the HUD's `TimeInterval.clockString`, which already widens to `H:MM:SS` past an hour.
- **AI-4:** `HighScoresStorage` is a local seam with a `UserDefaults` implementation. [`persistence-and-migration`](./persistence-and-migration.md) should replace it with the durable store it specifies, and take ownership of versioning `HighScoresData.schemaVersion`.

## 14. PRD Traceability

| PRD section | Covered by |
|---|---|
| High Scores (per-mode top-N, coupled score+time, ranking, time-to-beat, reset, stats) | §4–§9 |
| Scoring (floored ≥0 saved) | §4, §5 |
| Screens → High Scores, Win summary | §9 |
| Constraints (local-only, no accounts) | §2 |
