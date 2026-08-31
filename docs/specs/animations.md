# Feature Spec: Animations & Feedback

- **Status:** Draft
- **Owner:** TBD
- **Source PRD:** [`docs/PRD.md`](../PRD.md)
- **Spec sequence:** #6. Depends on [`game-engine`](./game-engine.md) (state transitions) and [`game-board-ui`](./game-board-ui.md) (card views, layout, `matchedGeometryEffect` namespace). Sequenced by [`hints-and-autocomplete`](./hints-and-autocomplete.md) for previews/finishes.
- **Target:** SwiftUI, iOS 17+.

---

## 1. Summary

Defines the motion vocabulary that makes state changes legible and satisfying: card **glide**, animated **deal** (initial + stock), **flip** on reveal, **run-clear** celebration, and the **win cascade** with summary. Crucially, it also defines the **instant, non-animated** paths (undo) and the explicit absences (no haptics, no sound, no invalid-move feedback). Animations are driven by engine state transitions and reuse the board's card views; they add no game logic.

## 2. Goals / Non-Goals

**Goals**
- A consistent set of animation configs (durations/curves) applied per event type.
- Smooth card movement via `matchedGeometryEffect` keyed on stable `Card.id`.
- Animated initial deal and each stock deal.
- Animated flip when a face-down card is revealed.
- Run-clear celebration when a K→A run clears.
- Win cascade animation plus a summary handoff.
- **Undo is instant** — an explicitly non-animated state application.
- Encode the absences: no haptics, no sound, no invalid-move feedback.

**Non-Goals**
- Game rules/state — [`game-engine`](./game-engine.md).
- Layout math, gestures, card art — [`game-board-ui`](./game-board-ui.md).
- Win-summary *content* (score/time/records) — [`high-scores`](./high-scores.md); this spec renders/sequences it.
- Reduce Motion handling — out of scope at launch (PRD), but see §8/AI.

## 3. User Stories

- **US-1** — As a player, cards glide smoothly to their new spot when I move them.
- **US-2** — As a player, the deal and each stock deal animate rather than snap.
- **US-3** — As a player, a revealed card flips over.
- **US-4** — As a player, completing a run plays a little celebration.
- **US-5** — As a player, winning plays the classic cascade and shows my summary.
- **US-6** — As a player, undo jumps back instantly with no reverse animation.

## 4. Animation Catalog

A single source of truth for timing so motion feels coherent:

```swift
enum Motion {
    static let glide     = Animation.spring(response: 0.30, dampingFraction: 0.82)
    static let deal      = Animation.easeOut(duration: 0.18)   // per card; staggered
    static let flip      = Animation.easeInOut(duration: 0.22)
    static let clear     = Animation.easeInOut(duration: 0.45)
    static let cascade   = Animation.easeIn(duration: 0.35)    // per card in win cascade
    static let instant   = Animation?.none                     // undo: no animation
    static let dealStagger: TimeInterval = 0.04                // between successive dealt cards
}
```

Values are starting points to tune on device (AI-1).

## 5. Event → Animation Mapping

State transitions come from the engine (via the `@Observable` session); the UI diffs old→new board and animates accordingly.

| Engine transition | Animation |
|---|---|
| Relocate run A→B | `matchedGeometryEffect` **glide** of each moved card (by `id`) from source to destination frames. |
| Initial deal | **Deal** each of the 54 cards from the deck origin to its column slot, **staggered** by `dealStagger` in deal order; tops finish face-up (flip at end of their deal). |
| Stock deal (+10) | **Deal**+stagger of 10 cards from the stock origin, one per column, landing face-up. |
| Auto-flip (reveal) | **Flip** (3D `rotation3DEffect` around Y) of the newly exposed card from back to face. |
| Run-clear (K→A) | **Clear** celebration: the 13 cards lift/sweep off to a "cleared" area with a brief flourish, then removed. |
| Win (8th run cleared) | **Win cascade** (§6) then summary. |
| **Undo** | **Instant** — apply restored state with `Motion.instant` (no glide, no reverse). |
| Auto-complete moves | Reuse **glide** + **clear** for each replayed move, then win. |
| Hint preview | Ghost-card **glide** to a destination and back (no state change) — sequenced by [`hints-and-autocomplete`](./hints-and-autocomplete.md). |

### 5.1 Driving matched-geometry moves
- The board owns `@Namespace var cardNS`; each `CardView` applies `.matchedGeometryEffect(id: card.id, in: cardNS)`.
- When the engine board changes inside `withAnimation(Motion.glide)`, SwiftUI interpolates each card from its old frame to its new one automatically. Because `Card.id` is stable across moves (engine §4), even duplicate ranks animate to the correct target.

## 6. Win Cascade & Summary

- **Cascade:** on win, the eight cleared runs' cards (or a representative deck) launch from their resting positions and **bounce down and across** the screen — the classic Solitaire cascade — using a lightweight custom animation (per-card initial velocity + gravity + floor bounce, driven by `TimelineView` or a keyframe/`CADisplayLink`-style loop; `cascade` timing per card).
- **Summary handoff:** after (or over) the cascade, present the Win screen summary sourced from [`high-scores`](./high-scores.md)'s `WinSummary` (final score, final time, records beaten). The cascade must not block the player from dismissing to the summary/menu.

## 7. Instant Undo (explicit non-animation)

- Undo must **not** animate. Apply the restored engine board within `withAnimation(nil)` / an explicit `Transaction` with `disablesAnimations = true`, so `matchedGeometryEffect` snaps rather than interpolates.
- This is a first-class requirement, not an omission: any code path that mutates the board must choose animated vs. instant deliberately (undo = instant; everything else = its mapped animation).

## 8. Absences (encoded requirements)

- **No haptics.** No `UIFeedbackGenerator` calls anywhere.
- **No sound.** No audio assets or `AVAudioPlayer`.
- **No invalid-move feedback.** A rejected move (snap-back from drag, inert tap) plays no shake/flash/haptic — the card simply returns or nothing happens.
- **Reduce Motion:** not handled at launch (PRD). Noted as low-effort and worth reconsidering — see AI-2. If added, it would swap animated events for `Motion.instant` and replace the cascade with a static win state.

## 9. Architecture & Concurrency

- All animation is `@MainActor` SwiftUI, driven by `@Observable` state diffs; no separate animation state machine beyond transient view state (e.g., cascade particles, hint ghost).
- Deal/stock origins and column slot frames come from [`game-board-ui`](./game-board-ui.md)'s frame registry, so motion respects the responsive layout.
- No blocking waits; long sequences (initial deal, cascade) are time-driven and interruptible (a tap can skip/settle them where sensible).

## 10. Acceptance Criteria

- [ ] Moving a card/run glides via matched geometry to the correct destination frame; duplicate-rank cards animate to their own targets (stable `id`).
- [ ] Initial deal and each stock deal animate with a visible stagger; dealt tops end face-up.
- [ ] Revealing a face-down card plays a flip.
- [ ] Clearing a K→A run plays the clear celebration and the cards are then gone.
- [ ] Winning plays the cascade and presents the summary; the player can dismiss without waiting for the cascade to end.
- [ ] **Undo applies instantly with no animation** (verified: no interpolation frames on the restored diff).
- [ ] No haptic, sound, or invalid-move feedback occurs on any path (including rejected drags and inert taps).
- [ ] Auto-complete replays with glide+clear then win; hint previews animate without mutating state.

## 11. Testing Strategy

- Motion is largely visual; verify with snapshot/preview review and manual on-device tuning.
- Unit-testable seams: the old→new board **diff** that decides which cards moved/flipped/cleared, and the undo path's transaction (assert animations disabled). Test these as pure functions independent of SwiftUI.
- Assert absence: a lint/grep-level check (and code review) that no haptic/audio APIs are referenced.

## 12. Open Questions / Action Items

- **AI-1:** Tune all `Motion` durations/curves on device; confirm deal stagger feels good for 54 cards without dragging.
- **AI-2:** Reconsider Reduce Motion support (PRD flags it as low-effort) — map events → instant and cascade → static.
- **AI-3:** Whether a tap can fast-forward/skip the initial deal and win cascade.
- **AI-4:** Cascade implementation choice (`TimelineView` + physics vs. keyframe animation) — pick after a spike.

## 13. PRD Traceability

| PRD section | Covered by |
|---|---|
| Animations & Feedback (movement, deal, flip, run-clear, win cascade, instant undo, no haptics/sound/invalid feedback) | §4–§8 |
| Win Screen (cascade + summary) | §6 |
| Undo (instant, no reverse animation) | §7 |
| Accessibility (Reduce Motion not at launch) | §8, AI-2 |
