# Feature Spec: Core Game Engine

- **Status:** Draft
- **Owner:** TBD
- **Source PRD:** [`docs/PRD.md`](../PRD.md)
- **Spec sequence:** #1 (foundational). Sibling specs planned: `game-board-ui`, `persistence-and-migration`, `high-scores`, `hints-and-autocomplete`, `animations`.
- **Target:** Swift 6 (strict concurrency), iOS 17+. Pure Swift, no UIKit/SwiftUI dependency.

---

## 1. Summary

The Core Game Engine is the UI-independent heart of the app: the domain model (cards, columns, stock), the rules of Spider Solitaire, **deal generation** (v1: random standard layout; guaranteed-winnable deals deferred — §6.3), the scoring model, and the undo system. It exposes a small, testable API that the board UI binds to and that the persistence layer serializes.

Everything in this spec is pure logic — deterministic, injectable-RNG, `Sendable` value types plus one `@MainActor` observable session. It carries no rendering, animation, gesture, or storage-format-migration concerns (those live in sibling specs), but it does define the `Codable` state shape those layers depend on.

## 2. Goals / Non-Goals

**Goals**
- Model the full Spider Solitaire rule set for 1/2/4-suit modes.
- Generate deals with the standard Spider layout (v1: random; guaranteed winnability deferred — §6.3).
- Implement the exact scoring model from the PRD, including farming-proof run credit.
- Provide unlimited, instant undo back to game start, persistable across app restarts.
- Provide single-tap auto-move destination resolution and legal-move queries.
- Expose a `Codable` game-state snapshot (with schema version) for resume-in-progress.
- Be trivially unit-testable (target: ≥ 80% coverage of engine logic).

**Non-Goals (deferred to sibling specs)**
- Rendering, layout, gestures, animations, card art (`game-board-ui`, `animations`).
- On-disk storage, `UserDefaults` keys, migration execution (`persistence-and-migration`).
- Leaderboard storage/ranking/stats UI (`high-scores`).
- Hint animation cycle and auto-complete UX (`hints-and-autocomplete`) — this spec provides the *logic* (legal-move enumeration, auto-complete solvability check); the UX wraps it.
- Timer UI ticking (engine holds elapsed time and start/pause/resume control only).

## 3. User Stories

Engine-facing slices of player-visible behavior:

- **US-1 — Start a game.** As a player, when I start a game in a chosen suit mode, I get a fresh board with the standard Spider layout (54 tableau cards, tops face-up; 50 in stock) using the correct card multiset for that mode. *(v1 deals are random — not guaranteed winnable; §6.3.)*
- **US-2 — Move a run.** As a player, I can move a single card or a valid same-suit descending run onto a card one rank higher (any suit) or onto an empty column, and the engine rejects illegal moves silently.
- **US-3 — Single-tap auto-move.** As a player, a single tap on a movable card sends it to the best legal destination by priority (same-suit continuation → any legal placement → empty column), or does nothing if no destination exists.
- **US-4 — Deal from stock.** As a player, I can deal a row of 10 cards (one per column), but not while any column is empty.
- **US-5 — Auto-clear & reveal.** As a player, completing a King→Ace same-suit run auto-clears it, and newly exposed face-down cards flip up automatically — neither costs a move.
- **US-6 — Score.** As a player, I start at 500, lose 1 per move and 1 per undo, and gain 100 per cleared run; the displayed score never shows below 0; I cannot farm points by clear/undo/re-clear.
- **US-7 — Undo.** As a player, I can undo any prior action unlimited times back to the game's start; undo jumps instantly and costs 1 point; there is no redo.
- **US-8 — Resume.** As a player, if I quit mid-game, I return to the exact same board, score, undo history, and elapsed time.
- **US-9 — Win / auto-complete.** As a player, clearing all 8 runs wins the game; when only trivial moves remain, the engine can finish the game automatically at no point cost.

## 4. Domain Model

All types are value types and `Sendable`. Cards carry a stable identity so duplicates (e.g., 8 identical Ace of Spades in 1-suit mode) remain distinguishable for animation and undo.

```swift
enum Suit: Int, CaseIterable, Codable, Sendable { case spades, hearts, diamonds, clubs }

enum Rank: Int, Comparable, CaseIterable, Codable, Sendable {
    case ace = 1, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king
    static func < (l: Rank, r: Rank) -> Bool { l.rawValue < r.rawValue }
    var isOneAbove: (Rank) -> Bool { { $0.rawValue == self.rawValue - 1 } } // self covers a card one lower
}

/// A physical card instance. `id` is a stable 0..<104 deck index (unique even across duplicates).
struct Card: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let rank: Rank
    let suit: Suit
    var isFaceUp: Bool
}

enum SuitMode: Int, Codable, Sendable {
    case one = 1, two = 2, four = 4
    /// Suits actually present in the deck for this mode.
    var suits: [Suit] {
        switch self {
        case .one:  return [.spades]
        case .two:  return [.spades, .hearts]
        case .four: return Suit.allCases
        }
    }
    /// Copies of each (rank,suit) pair so the deck always totals 104.
    var copiesPerCard: Int { 8 / rawValue }   // 1→8, 2→4, 4→2
}
```

### 4.1 Board vs. Session vs. State

Three layers, deliberately separated:

- **`Board`** — the mutable-by-value core: `tableau` (10 columns), `stock`, `completedRuns`. Pure data + pure rule methods. This is what undo snapshots.
- **`GameState`** — `Codable` aggregate = `Board` + `initialBoard` (the deal as first laid out) + lifetime counters + mode + elapsed + undo stack + `schemaVersion`. This is what persistence serializes.
- **`GameSession`** — `@MainActor @Observable final class` wrapping a `GameState`, exposing intent methods (`tap`, `move`, `deal`, `undo`, `restart`, `newGame`) and derived values (`displayScore`, `isWon`) to the UI.

```swift
struct Board: Hashable, Codable, Sendable {
    var tableau: [[Card]]          // exactly 10 columns; index 0 = bottom, last = top
    var stock: [Card]              // remaining stock; count is always a multiple of 10
    var completedRuns: [CompletedRun]   // cleared K→A runs (identity retained)
    var dealsRemaining: Int { stock.count / 10 }
}

/// A cleared run. Retained for restore-on-undo, win animation, and score derivation.
struct CompletedRun: Hashable, Codable, Sendable {
    let cardIDs: [Int]   // the 13 card ids, King→Ace
    let suit: Suit
}

struct GameState: Codable, Sendable {
    static let currentSchemaVersion = 2   // v2 added initialBoard
    var schemaVersion = GameState.currentSchemaVersion
    var mode: SuitMode
    var board: Board
    var moveCount: Int              // monotonic; forward moves only
    var undoCount: Int              // monotonic; undo actions only
    var elapsed: TimeInterval       // accumulated play time (see §11)
    var undoStack: [Board]          // pre-action board snapshots (see §9)
    var timerStarted: Bool          // false until the first forward move
}
```

## 5. Rules & Forward Operations

### 5.1 Movable runs

- A **movable run** in a column is a set of contiguous cards from some index to the column top that are all face-up, same suit, and strictly descending by one rank each (e.g., ♠9-♠8-♠7).
- `topRun(_ column:) -> Range<Int>` returns the **maximal** movable run at the top.
- Tapping/selecting card at index `i` yields the run `i...top` **iff** that slice is itself a valid movable run; otherwise the selection is empty (tap ignored). Drag may target any sub-run that is valid.

### 5.2 Placement

`canPlace(run:onto:) -> Bool`:
- Destination column is empty → **always legal** (any card or run may move onto an empty column), **or**
- Destination top card rank == run's top (highest) card rank + 1 — **any suit** (placement is suit-agnostic; only *movement as a group* requires same suit).

### 5.3 Stock deal

- Precondition: **no column is empty**. If any column is empty, the deal is rejected (silent no-op).
- Effect: pop the next 10 cards from stock, deal one **face-up** to the top of each column (column order 0→9). Deals never flip and never require same-rank alignment.
- Counts as **one** move (§8), not ten.

### 5.4 Auto-clear (run completion)

After *any* board mutation (move or deal), run the clear-and-flip fixpoint:

1. For each column, if the top 13 cards form a complete **King→Ace same-suit** run, remove them and append a `CompletedRun` (identity = those 13 ids).
2. Any column whose new top is face-down flips it **face-up** (auto-reveal).
3. Repeat 1–2 until no change (a deal can complete runs in multiple columns; a clear can expose another complete run beneath).

Auto-clears and auto-flips are **not** moves and cost no points.

### 5.5 Win

`isWon == board.completedRuns.count == 8` (all 8 runs cleared). Holds identically in all modes.

## 6. Deal Generation

### 6.1 v1 — random deals via `DealProvider`

Deals come from an injected provider, so tests can supply a controlled deal:

```swift
protocol DealProvider: Sendable {
    func makeDeal<R: RandomNumberGenerator>(mode: SuitMode, using rng: inout R) -> Board
}
```

`RandomDealProvider` (the v1 default in `GameSession`) shuffles the mode's
104-card multiset and lays out a standard board via `DealFormat.board(from:)`:
heights `[6,6,6,6,5,5,5,5,5,5]`, only column tops face-up, 50 in stock, ids
`0..<104` by position. **v1 deals are not guaranteed winnable.**

### 6.2 Structure guarantees (asserted by `DealFormatTests`)

Every dealt board satisfies:
- `tableau.count == 10`; heights == `[6,6,6,6,5,5,5,5,5,5]`; `stock.count == 50`.
- Only each column **top** is face-up; all 44 other tableau cards face-down.
- Full 104-card multiset matches `mode` (correct suits, `copiesPerCard` each).
- No `completedRuns`.

### 6.3 Winnability — deferred (later phase)

Guaranteed-solvable deals are a **planned later phase**, not in v1 (PRD → Deal
Generation). The intended approach is an **offline pre-generated pool of solvable
deals** bundled with the app (deal random layouts, filter with a bounded Spider
solver, keep only the winnable ones, select at runtime for free). The hard part
is the solver; shipping random deals now unblocks the rest of the app. Because
everything depends only on the `DealProvider` seam, a pool-backed provider drops
in later with no other changes.

## 7. Auto-Move Resolution (single tap)

`func autoMoveDestination(forRunAt column: Int, index: Int) -> Int?`

Given the tapped card's movable run `G` (§5.1; empty ⇒ return `nil`), choose a destination column by **priority**, evaluating only legal destinations (§5.2), excluding the source column:

1. **Same-suit continuation** — destination top is `G.top`'s suit and rank `G.top+1` (extends a same-suit run). 
2. **Any legal descending placement** — destination top rank `G.top+1`, different suit.
3. **Empty column.**

- Return the first non-empty match in priority order; within a tier, **tie-break by leftmost column index**.
- If no tier matches, return `nil` (no move; **no feedback** per PRD).
- Drag-and-drop bypasses this and uses an explicit target validated by `canPlace`.

*(Refinement backlog: prefer a destination that reveals a face-down card or avoids breaking a longer run. v1 uses leftmost for determinism/testability.)*

## 8. Scoring Model

Score is **derived**, not accumulated — this makes farming structurally impossible and undo trivially correct.

```
internalScore = 500 - moveCount - undoCount + 100 * board.completedRuns.count
displayScore  = max(0, internalScore)          // floored at 0 for display AND leaderboard save
```

- `moveCount` increments by 1 on each committed **forward move**: a single-card relocate, a same-suit-run relocate (one move for the whole group), or a stock deal (one move for the whole row of 10).
- `undoCount` increments by 1 on each undo action.
- **Both counters are monotonic** — undo does **not** refund a move's penalty (PRD penalizes moves and undos independently).
- Auto-clears, auto-flips, hints, and auto-complete moves increment **nothing**.
- Run credit derives from the **current** cleared-run count. A clear/undo/re-clear cycle therefore nets exactly **+100** once (undo restores the pre-clear board, dropping the count; re-clear restores it — the run is never double-credited). This satisfies the PRD's "cleared-run identity" requirement structurally, without event bookkeeping.

**Worked example** — move a run to clear ♠K→A, then undo, then re-clear:

| Action | moveCount | undoCount | clearedRuns | internalScore |
|---|---|---|---|---|
| start | 0 | 0 | 0 | 500 |
| move (clears run) | 1 | 0 | 1 | 599 |
| undo | 1 | 1 | 0 | 498 |
| move (re-clears) | 2 | 1 | 1 | 597 |

Net effect of the churn: the run is credited once; the player paid for the moves and the undo. No farming.

## 9. Undo Model

**Mechanism: board snapshots** (not command inversion).

- Rationale: forward actions have **compound side effects** — a deal can complete runs in several columns and trigger multiple flips; a relocate can trigger a clear plus a flip. Inverting each side-effect chain by hand is error-prone. Snapshotting the small (`≤104`-card) `Board` value before each action is provably correct, makes "undo jumps instantly, no animation" a single assignment, and is negligible in memory at solitaire scale.

Algorithm:
- **Commit a forward action:** `undoStack.append(board)` (pre-action copy) → mutate `board` → run clear-and-flip fixpoint → `moveCount += 1` → start timer if first move.
- **Undo:** guard `!undoStack.isEmpty`; `board = undoStack.removeLast()`; `undoCount += 1`. (The popped snapshot *is* the restored board; nothing is re-pushed.)
- **No redo:** any new forward action after an undo simply pushes the current board; discarded futures are never stored.
- **Scoring** needs no special handling — it re-derives from restored `completedRuns.count` and the monotonic counters (§8).
- **Persistence:** `undoStack` is `Codable` and part of `GameState`, so undo history survives app restarts (PRD resume requirement). Optional compact card encoding (pack rank/suit/faceUp into a byte) can shrink the serialized stack; not required for correctness.

## 10. Auto-Complete

- **Availability** (`canAutoComplete`): `stock.isEmpty` **and** every tableau card `isFaceUp` **and** a bounded internal greedy solver confirms the board can be fully cleared with only legal moves.
- **Execution:** replays the greedy solver's move list; each executed relocate is applied but increments **no** counters (points-free per PRD). Ends in the won state.
- The greedy solver is engine-internal and reused by the availability check; the hint/auto-complete UX (`hints-and-autocomplete`) wraps it.

## 11. Timing

- `elapsed: TimeInterval` lives in `GameState`; the running clock is driven by the session, not the pure core.
- `timerStarted` flips true on the **first forward move**; `elapsed` accumulates only while `timerStarted && !paused`.
- `GameSession` exposes `pause()` / `resume()` (called on background/foreground and menu open/close) and accrues elapsed via an **injected clock** (`protocol Clock { var now: TimeInterval { get } }`) so tests are deterministic.
- Only a win freezes and records final `elapsed` (consumed by `high-scores`). Lost/abandoned games record nothing.

## 12. Concurrency (Swift 6)

- All model value types are `Sendable`; `RandomDealProvider` is a `Sendable` value type (just a shuffle), trivially cheap on the main actor.
- `GameSession` is `@MainActor @Observable`; all UI-facing intent methods are main-actor isolated.
- No shared mutable global state; RNG and clock are injected. Zero data races by construction — no strict-concurrency suppressions permitted.

## 13. Public API Sketch

```swift
@MainActor @Observable
final class GameSession {
    private(set) var state: GameState
    var displayScore: Int { max(0, internalScore) }
    var isWon: Bool { state.board.completedRuns.count == 8 }
    var canDeal: Bool { !state.board.tableau.contains(where: \.isEmpty) && state.board.dealsRemaining > 0 }
    var canAutoComplete: Bool { /* §10 */ }

    init(mode: SuitMode, rng: inout some RandomNumberGenerator, clock: some Clock)
    init(resuming state: GameState, clock: some Clock)     // resume-in-progress

    // Intents (return whether anything changed; illegal intents are silent no-ops)
    @discardableResult func tap(column: Int, index: Int) -> Bool     // single-tap auto-move
    @discardableResult func move(from: Int, index: Int, to: Int) -> Bool  // explicit drag target
    @discardableResult func deal() -> Bool
    @discardableResult func undo() -> Bool
    func autoComplete()
    func newGame(mode: SuitMode, rng: inout some RandomNumberGenerator)

    func pause(); func resume()
}

// Pure, UI-free, exhaustively testable:
struct Rules {
    static func topRun(of column: [Card]) -> Range<Int>
    static func canPlace(run: ArraySlice<Card>, onto column: [Card]) -> Bool
    static func autoMoveDestination(board: Board, column: Int, index: Int) -> Int?
    static func applyClearsAndFlips(_ board: inout Board)        // §5.4 fixpoint
}

protocol DealProvider: Sendable {                               // §6.1
    func makeDeal<R: RandomNumberGenerator>(mode: SuitMode, using rng: inout R) -> Board
}
// RandomDealProvider (v1 default): shuffles the multiset into a standard board.
```

## 14. State & Serialization Contract

- `GameState` is `Codable` and self-describing via `schemaVersion` (currently `2`; v2 added `initialBoard`, the deal as first laid out, so Restart can replay it).
- The engine only *reads/writes* the versioned value; **migration is executed by `persistence-and-migration`**, which, on version mismatch, either migrates forward or fails gracefully (never corrupts a running app — PRD).
- Invariants the engine guarantees for any `GameState` it emits: 104-card multiset matches `mode`; `stock.count % 10 == 0`; `tableau.count == 10`; `undoStack` entries are structurally valid boards.

## 15. Acceptance Criteria

Deal generation (v1 — random)
- [ ] For each mode, `RandomDealProvider.makeDeal` returns a board meeting the §6.2 structure guarantees (heights, face-up tops only, 50 stock, correct multiset, no cleared runs).
- [ ] Same seed ⇒ identical board (deterministic under injected RNG).
- [ ] *(Deferred, §6.3)* Guaranteed winnability via an offline solvable pool — not a v1 criterion.

Rules
- [ ] `topRun` returns only same-suit, strictly-descending, face-up top runs.
- [ ] `canPlace` allows empty-column placement always, and non-empty only when dest top == run top + 1 (any suit).
- [ ] Deal is rejected when any column is empty; otherwise deals exactly 10 face-up cards, one per column.
- [ ] Clear-and-flip fixpoint clears every top K→A same-suit run and flips every exposed face-down top, iterating to stability (incl. multi-column clears from one deal).

Auto-move
- [ ] Destination follows priority same-suit → any-legal → empty, leftmost tie-break; returns `nil` (no-op) when no legal destination exists.

Scoring
- [ ] `displayScore == max(0, 500 - moveCount - undoCount + 100*clearedRuns)` at all times.
- [ ] A run-relocate and a 10-card deal each cost exactly 1 move; auto-clears/flips/hints/auto-complete cost 0.
- [ ] The §8 clear/undo/re-clear table reproduces exactly (net +100, no farming).
- [ ] Internal score may be negative; display and saved value floor at 0.

Undo
- [ ] Undo restores the exact prior board (tableau, stock, cleared runs) for single moves, run moves, and deals — including reversal of side-effect flips and clears.
- [ ] Undo is available back to the first action and unavailable at game start.
- [ ] Each undo increments `undoCount` by 1 and never decrements `moveCount`. No redo path exists.

Lifecycle
- [ ] A `GameState` round-trips through `Codable` unchanged, including a non-empty `undoStack` and mid-game `elapsed`.
- [ ] `init(resuming:)` restores a session whose board, score, undo depth, and elapsed match the saved state.
- [ ] Timer starts only on the first forward move and only a win records final elapsed.

Win / auto-complete
- [ ] `isWon` true iff 8 runs cleared; `canAutoComplete` true only when stock empty, all face-up, and greedily solvable; `autoComplete()` finishes at 0 point cost.

## 16. Testing Strategy

- **Pure-function unit tests** (Swift Testing `@Test`/`#expect`) for `Rules`, scoring derivation, auto-move priority, and undo restore — table-driven where possible.
- **Deal structure tests** (`DealFormatTests`): for each mode, assert the §6.2 structure guarantees (heights, tops-only face-up, 50 stock, correct multiset, unique ids).
- **Undo differential test:** apply a random legal action, snapshot, undo, and assert board equality with the pre-action snapshot across fuzzed sequences.
- **Serialization test:** encode→decode `GameState` fuzzed mid-game; assert equality and schema version.
- Injected RNG + injected `Clock` make every test deterministic. No UI or XCTest-UI in this layer (PRD/CLAUDE: no UITests during scaffolding).

## 17. Open Questions / Action Items

- **AI-1 (later phase):** Guaranteed-winnable deals (§6.3) — build a competent bounded Spider solver and offline pre-generated pool, then swap `RandomDealProvider` for a pool-backed provider. v1 ships random deals.
- **AI-2:** Define the greedy auto-complete solver's precise stopping/coverage guarantee (sufficient-condition heuristic vs. complete search) — affects when the auto-complete affordance appears.
- **AI-3:** Decide compact `undoStack` encoding now vs. later (only matters if serialized save size becomes a concern).
- **AI-4:** Auto-move tie-break refinement (reveal-a-card / preserve-longer-run heuristics) — deferred past v1.
- **PRD carry-overs (not engine):** CC0 SVG deck selection; app name/icon/metadata.

## 18. PRD Traceability

| PRD section | Covered by |
|---|---|
| Game Rules | §5 |
| Difficulty (Suit Selection) | §4 `SuitMode`, §6.2 multiset |
| Deal Generation (v1 random; winnability deferred) | §6 |
| Scoring (incl. no-farming, floor at 0) | §8 |
| Undo (unlimited, instant, −1, no redo) | §9 |
| Auto-Complete | §10 |
| Input & Interaction (single-tap priority, drag) | §7 |
| Timing (start/pause/resume, resume persists) | §11, §14 |
| Game State & Lifecycle (resume-in-progress) | §4.1, §14 |
| Persistence & Schema Versioning | §14 (shape only; execution in sibling spec) |
| Hints | Logic hooks in §7/§10; UX in `hints-and-autocomplete` |
