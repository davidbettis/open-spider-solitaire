# Feature Spec: Hints & Auto-Complete

- **Status:** Hints implemented; Auto-Complete (§5) still unwired in the UI
- **Owner:** TBD
- **Source PRD:** [`docs/PRD.md`](../PRD.md)
- **Spec sequence:** #5. Depends on [`game-engine`](./game-engine.md) (legal-move enumeration, auto-complete logic) and [`game-board-ui`](./game-board-ui.md) / [`animations`](./animations.md) (presentation).
- **Target:** SwiftUI, iOS 17+.

---

## 1. Summary

Two assists that share the engine's rule logic:
- **Hints** — a **free** (no point cost) preview that animates a candidate card to each legal destination in turn, cancelable by tapping anywhere. Preview-only: it changes **no** game state.
- **Auto-Complete** — offered when only trivial moves remain; finishes the game automatically at **no** point cost.

This spec owns the UX state machines and candidate ordering; the underlying legality/solvability lives in the engine (§7, §10 of the engine spec).

## 2. Goals / Non-Goals

**Goals**
- Cycle a hint through legal moves, one card→destination at a time, animated.
- Cancel the hint cycle on any tap.
- Keep hints **free** — they cost real time (timer keeps running) but zero points, and mutate no state.
- Detect when auto-complete is available and offer it.
- Execute auto-complete to a win at zero point cost.

**Non-Goals**
- The move-legality and greedy-solver algorithms themselves — [`game-engine`](./game-engine.md).
- Card motion primitives — [`animations`](./animations.md); this spec sequences them.
- Scoring changes — hints/auto-complete are point-neutral by the engine's derived-score model.

## 3. User Stories

- **US-1** — As a stuck player, I tap Hint and watch a card glide to each place it could legally go.
- **US-2** — As a player, I tap anywhere to stop the hint cycle immediately.
- **US-3** — As a player, hints never cost me points and never change the board.
- **US-4** — As a player, when the game is basically over, it offers to finish itself.
- **US-5** — As a player, letting it auto-finish doesn't cost me points.

## 4. Hints

### 4.1 Candidate enumeration
`HintProvider` builds the ordered list of candidate moves from the current board using engine rules — **without mutating state**:

```swift
struct HintCandidate: Identifiable {
    let id: Int
    let sourceColumn: Int
    let runRange: Range<Int>     // the movable run being suggested
    let destinationColumn: Int   // a legal destination
}

struct HintProvider {
    func candidates(for board: Board) -> [HintCandidate]
}
```

- For each column, take its top movable run (and legal sub-runs), and for each, enumerate legal destinations (engine `Rules.canPlace`).
- **Ordering is a plain scan, deliberately not strategic**: source column left to right, shortest run first within a column, then destination left to right. Hints report the moves that *exist*; ranking them by quality would make the assist play the game for the player. (This supersedes an earlier draft that ordered by the auto-move priority.)
- Every legal move is cycled — there is no top-K cap (resolves AI-3).
- De-duplicate trivially equivalent suggestions (same run to the same destination).
- If there are **no** candidates, the Hint control is a no-op (optionally briefly disabled); no feedback beyond that (consistent with "no invalid-move feedback").

### 4.2 Hint cycle state machine
UI-only ephemeral state in a `@MainActor @Observable HintController` (or `@State` in the board):

```
idle ──tap Hint──▶ cycling(index: 0)
cycling(i) ──animation completes──▶ cycling(i+1 mod count)   // loops through candidates
cycling(_) ──any board tap / gesture / control──▶ idle       // cancel
idle ──game state changes (move/deal/undo)──▶ idle           // candidates invalidated
```

- On entering `cycling(i)`, a translucent **ghost** of the suggested run glides from where it sits to the slot it would land in, and the destination gets a ring (`HintLayer`). The real cards do not move. Positions come from `BoardLayout`, so this needs nothing from [`animations`](./animations.md) (resolves AI-1).
- **Cancel:** any tap anywhere (board, HUD, control) returns to `idle` and clears the preview immediately.
- **Invalidation:** any actual state mutation exits the cycle (candidates may be stale).
- The **timer keeps running** during hints (PRD: hints cost time, not points). No counters change.

## 5. Auto-Complete

### 5.1 Availability
Bind to engine `session.canAutoComplete` (§10 engine spec: stock empty, all cards face-up, greedily solvable). When it flips true, present a non-intrusive **"Finish game"** affordance (button/banner).

### 5.2 Execution
- On tap, call `session.autoComplete()`. The engine replays its greedy solution, mutating state to the won board with **no** counter changes (points-neutral).
- The UI sequences the finishing moves with animation (glide + run-clear celebration, then the win cascade) via [`animations`](./animations.md).
- Auto-complete is not undoable step-by-step in v1 (it ends the game); undo semantics for the pre-auto-complete state are out of scope unless AI-2 decides otherwise.

## 6. Interaction Rules

- Hint and auto-complete are mutually exclusive with an in-progress drag: starting either cancels a hint; starting a drag cancels a hint.
- Neither assist ever produces invalid-move feedback.
- Both are reachable from the ControlBar ([`game-board-ui`](./game-board-ui.md) §6.3); auto-complete additionally surfaces contextually when available.

## 7. Architecture & Concurrency

- `HintProvider` is pure and `Sendable`; enumeration reuses engine `Rules`.
- `HintController` is `@MainActor @Observable`, holds only ephemeral cycle state, and reads the engine board but never mutates it.
- Auto-complete delegates entirely to the engine; this spec only triggers and sequences presentation.

## 8. Acceptance Criteria

- [x] Hint enumerates all legal candidate moves for the current board, in scan order, de-duplicated.
- [x] The hint cycle advances through candidates and loops; it animates previews without changing the board or any counter.
- [x] Any tap cancels the cycle immediately and clears the preview.
- [x] A board mutation (move/deal/undo) exits the hint cycle.
- [x] With no legal moves, Hint is an inert no-op.
- [x] Hints cost 0 points and never touch `moveCount`/`undoCount`/score; the timer keeps running during a hint.
- [ ] The auto-complete affordance appears exactly when `session.canAutoComplete` is true.
- [ ] `autoComplete()` finishes to a win with 0 point cost.

## 9. Testing Strategy

- `HintProvider` unit tests: candidate completeness, sub-run enumeration, scan ordering, de-dup, empty-board-of-moves case (pure, no UI).
- `HintController` state-machine tests: cycle advance/loop, cancel-on-tap, invalidate-on-mutation, score/counter invariance.
- Auto-complete: availability gating and points-neutral completion via engine (engine owns the solver tests).

## 10. Open Questions / Action Items

- ~~**AI-1:** Hint preview style~~ — **resolved**: gliding ghost run + destination ring, positioned from `BoardLayout`.
- **AI-2:** Should the pre-auto-complete board be restorable via undo after auto-complete, or is auto-complete terminal? (v1: terminal.)
- ~~**AI-3:** Cap the number of hint candidates cycled~~ — **resolved**: no cap; the cycle walks every legal move, since hints enumerate rather than rank.

## 11. PRD Traceability

| PRD section | Covered by |
|---|---|
| Hints (animated to each destination, tap cancels, free) | §4 |
| Auto-Complete (offered on trivial boards, no point cost) | §5 |
| Scoring (hints/auto-complete cost nothing) | §4.2, §5.2 |
| Animations & Feedback (no invalid feedback) | §6 |
