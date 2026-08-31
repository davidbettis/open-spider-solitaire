# Feature Spec: Persistence & Migration

- **Status:** Draft
- **Owner:** TBD
- **Source PRD:** [`docs/PRD.md`](../PRD.md)
- **Spec sequence:** #3. Depends on [`game-engine`](./game-engine.md). Serves [`high-scores`](./high-scores.md).
- **Target:** Swift 6, iOS 17+. Local-only, offline, no iCloud.

---

## 1. Summary

Persistence saves and restores everything the player expects to survive an app quit: the **in-progress game** (tableau, stock, score counters, undo stack, elapsed time) and **durable data** (settings, high scores). It owns the on-disk format, the save/load lifecycle, and the **schema-versioned migration** path that upgrades old saves or fails gracefully without corrupting the app. It executes the versioned `GameState` contract the engine defines (§14 of the engine spec) but adds no game logic.

## 2. Goals / Non-Goals

**Goals**
- Resume-in-progress: full `GameState` round-trips exactly, including `undoStack` and `elapsed`.
- Durable per-mode high scores and settings survive restarts.
- Every persisted payload is **schema-versioned**; a version mismatch triggers migration.
- **Graceful failure:** unmigratable or corrupt data is discarded cleanly (fresh start), never crashes or corrupts a running app.
- Saves are cheap, non-blocking, and safe against mid-write termination.

**Non-Goals**
- iCloud/network sync (PRD: local-only) — explicitly excluded.
- Analytics/tracking (PRD: none).
- The *shape* of `GameState` and high-score models (owned by [`game-engine`](./game-engine.md) and [`high-scores`](./high-scores.md)); this spec stores and versions them.
- Encryption (no sensitive data; not required).

## 3. User Stories

- **US-1** — As a player, if I quit mid-game (or get a call, or background the app), I come back to the exact same board, score, undo history, and elapsed time.
- **US-2** — As a player, my high scores and chosen settings are still there after I fully restart the app.
- **US-3** — As a player, if a save from an old version can't be understood, the app still opens fine (fresh) instead of crashing.

## 4. Stores

Two independent stores, chosen by size and write frequency:

| Store | Payload | Backing | Why |
|---|---|---|---|
| **GameSnapshotStore** | `GameState` (can be larger — includes `undoStack`) | JSON file, atomic write, in app **Application Support** | Bigger, written often mid-play; a file with atomic replace avoids `UserDefaults` bloat and partial writes. |
| **DurableStore** | Settings + high scores (small) | `Codable` blobs in `UserDefaults` (or a small JSON file) | Tiny, infrequent, simple. |

Both payloads carry a `schemaVersion`. `GameState.schemaVersion` is defined by the engine (currently `1`); the durable payload defines its own.

## 5. Persisted Envelopes

Everything is wrapped so the version is readable **before** decoding the body — enabling migration without a failed full decode.

```swift
struct PersistedEnvelope<Body: Codable>: Codable {
    var schemaVersion: Int
    var body: Body
}
```

- **Game snapshot:** `PersistedEnvelope<GameState>` (present only while a game is in progress; deleted on win or explicit new-game-discard).
- **Durable:** `PersistedEnvelope<DurableData>` where `DurableData = { settings, leaderboardsByMode, statsByMode }` (fields owned by [`high-scores`](./high-scores.md)).

## 6. Lifecycle

### 6.1 Save triggers (game snapshot)
- **Debounced autosave** after each committed engine action (move/deal/undo/auto-complete) — coalesced (e.g., ~0.5 s) to avoid churn during rapid play.
- **Immediate synchronous-enough save** on `scenePhase` → `.inactive`/`.background` (the reliable "app is leaving" signal on iOS) and before `newGame`.
- **Delete** the snapshot on **win** and on confirmed **new game** (the old in-progress game is gone).

### 6.2 Save triggers (durable)
- On high-score insert, stats change, or settings change (infrequent → save immediately).

### 6.3 Load (launch)
1. Read the durable envelope; migrate if needed (§7); on unrecoverable failure, reset to defaults.
2. Read the game snapshot envelope if present; migrate if needed; on unrecoverable failure, delete it and start with no resumable game.
3. Hand the (possibly nil) restored `GameState` to the app shell, which either resumes via `GameSession(resuming:)` or shows the menu.

### 6.4 Atomicity
- File writes go to a temp file then atomically replace the target (`Data.write(to:options:.atomic)`), so a crash mid-write never leaves a half-written save — the previous good save survives.

## 7. Migration

```swift
protocol Migration {
    var from: Int { get }         // input schema version
    var to: Int { get }           // output schema version (from + 1)
    func migrate(_ json: Data) throws -> Data   // structural upgrade on the raw payload
}

struct MigrationChain {
    let migrations: [Migration]   // ordered, contiguous by version
    func upgrade(_ data: Data, from: Int, to current: Int) throws -> Data
}
```

- On load, read `schemaVersion` from the envelope. If `== current`, decode directly. If `< current`, apply migrations `from → from+1 → … → current` in order, then decode.
- If `> current` (a downgrade — save from a newer app version): treat as **unmigratable** → discard gracefully.
- A migration that throws, or a missing step in the chain, is **unmigratable** → discard gracefully (§8). No partial or lossy in-place mutation of live app state.
- Migrations operate on **raw JSON**, not typed models, so old shapes need not be kept compilable as Swift types.

## 8. Graceful Failure

Any of: unreadable file, JSON decode error, unknown/newer version, failed migration, or invariant violation on the decoded value ⇒
- The offending store is treated as absent: game snapshot → deleted, resume skipped; durable → reset to defaults (empty leaderboards, default settings).
- The app **continues normally**; no crash, no user-facing error required (a silent, clean fallback per PRD "fails gracefully without corrupting the app").
- Optional: log the failure to console for debugging only (no analytics).

## 9. Architecture & Concurrency

- `actor PersistenceService` isolates all disk I/O; public API is `async`.
  ```swift
  actor PersistenceService {
      func saveGame(_ state: GameState) async
      func loadGame() async -> GameState?
      func deleteGame() async
      func saveDurable(_ data: DurableData) async
      func loadDurable() async -> DurableData        // never throws; returns defaults on failure
  }
  ```
- All types persisted are `Sendable` value types (engine + high-scores models already are).
- Autosave is fire-and-forget from the `@MainActor` session into the actor (debounced); the background/terminate save is `await`ed within the scene-phase transition as far as iOS allows.
- No blocking of the main thread for I/O.

## 10. Storage Locations & Keys

- Game snapshot file: `Application Support/OpenSpiderSolitaire/game.json` (excluded from iCloud backup is optional; local-only either way).
- Durable: `UserDefaults` key `durable.v{n}` holding the encoded envelope, **or** `Application Support/.../durable.json`. Recommend the file for consistency and to keep `UserDefaults` lean; decide in AI-1.
- Directory created on first launch if absent.

## 11. Acceptance Criteria

- [ ] A mid-game `GameState` (non-empty `undoStack`, non-zero `elapsed`) saved then loaded is byte-for-value identical.
- [ ] Killing the app during play and relaunching resumes the exact board, score, undo depth, and elapsed time.
- [ ] Winning or confirming a new game deletes the in-progress snapshot; next launch shows no resumable game.
- [ ] Durable data (leaderboards, stats, settings) survives a full restart.
- [ ] A save file with `schemaVersion` below current is migrated stepwise and decodes correctly (fixture-driven).
- [ ] A corrupt/truncated file, an unknown/newer version, and a throwing migration each result in a clean fallback (deleted snapshot / default durable) with no crash.
- [ ] A simulated crash mid-write (temp file present, target untouched) leaves the previous good save intact.
- [ ] All disk I/O is off the main thread; no UI hang under rapid autosave.

## 12. Testing Strategy

- Round-trip encode/decode of fuzzed `GameState` and `DurableData`.
- Migration tests from versioned JSON fixtures (v0→v1 seeded now to exercise the chain even with a single step).
- Corruption fixtures: truncated JSON, wrong types, `schemaVersion` = current+1, unknown fields.
- Atomicity test: assert temp-then-replace; simulate interrupted write and verify prior save survives.
- Debounce/coalescing test for autosave frequency.

## 13. Open Questions / Action Items

- **AI-1:** `UserDefaults` vs. dedicated JSON file for the durable store (leaning file for consistency).
- **AI-2:** Autosave debounce interval and whether to also snapshot after auto-clears (no player action) — likely yes, since board changed.
- **AI-3:** Exact background-save budget on iOS (background task assertion) to guarantee the terminate-time save completes.

## 14. PRD Traceability

| PRD section | Covered by |
|---|---|
| Persistence & Schema Versioning | §5, §7, §8 |
| Game State & Lifecycle (resume-in-progress) | §6 |
| Timing (elapsed persists across sessions) | §6.1, §11 |
| High Scores (persisted locally) | §4, §5 (storage), logic in [`high-scores`](./high-scores.md) |
| Constraints (offline, no iCloud, no tracking) | §2, §4 |
