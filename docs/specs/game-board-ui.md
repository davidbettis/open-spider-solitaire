# Feature Spec: Game Board UI

- **Status:** Draft
- **Owner:** TBD
- **Source PRD:** [`docs/PRD.md`](../PRD.md)
- **Spec sequence:** #2. Depends on [`game-engine`](./game-engine.md). Peers: [`animations`](./animations.md), [`hints-and-autocomplete`](./hints-and-autocomplete.md).
- **Target:** SwiftUI, iOS 17+, iPhone only, portrait + landscape.

---

## 1. Summary

The Game Board UI renders the live game — the 10-column tableau, the stock, the HUD (score, timer, deals remaining), and the action controls (undo, hint, new game) — and translates player gestures (single-tap auto-move, drag-and-drop) into engine intents. It owns **no game rules and no persisted state**; it binds to the engine's `GameSession` and to UI-only ephemeral state (the in-flight drag). Visual motion is specified in [`animations`](./animations.md); this spec covers structure, layout, and input.

## 2. Goals / Non-Goals

**Goals**
- Responsive layout for all current iPhone sizes in both orientations, including columns that grow very tall.
- Single-tap auto-move and drag-and-drop with explicit destination control, disambiguated cleanly.
- HUD: floored live score, live MM:SS timer, deals-remaining stock indicator.
- Controls: undo, hint, new-game (with in-progress confirmation).
- Pause the game timer when a menu opens or the app backgrounds; resume on return.
- A pure, unit-testable layout model.

**Non-Goals**
- Rules, scoring, undo logic, deal generation — [`game-engine`](./game-engine.md).
- Card glide/deal/flip/clear/win motion — [`animations`](./animations.md).
- Hint cycle behavior and auto-complete affordance — [`hints-and-autocomplete`](./hints-and-autocomplete.md).
- Menu, high-scores, win screens beyond navigation hooks — [`high-scores`](./high-scores.md) and app-shell.
- Card face/back art selection (CC0 deck) — PRD action item; this spec consumes a `CardImageProvider` abstraction.

## 3. User Stories

- **US-1** — As a player, I see all 10 columns, my score, elapsed time, and how many stock deals remain, without scrolling the whole screen.
- **US-2** — As a player, tapping a movable card sends it to the best legal spot automatically.
- **US-3** — As a player, I can drag a card or run to a specific column when I want to choose the destination.
- **US-4** — As a player, invalid moves simply don't happen — no error, no buzz.
- **US-5** — As a player, the board looks right on my iPhone in portrait and landscape, even when a column gets long.
- **US-6** — As a player, starting a new game mid-play asks me to confirm.
- **US-7** — As a player, the timer pauses when I open a menu or leave the app.

## 4. Screen Structure

```
GameBoardView
├─ HUDBar                     // top: set slots · score/timer · deck (deal)
│   ├─ SetSlots               // left: 8 completed-set slots
│   └─ DeckIndicator          // right: face-down deck, taps to deal
├─ TableauView                // 10 ColumnViews in an HStack, GeometryReader-sized
│   └─ ColumnView × 10
│       └─ CardView × n       // fanned; face-down tighter, face-up looser
├─ DragLayer (overlay)        // renders the run currently being dragged
├─ FinishGameButton (overlay) // auto-complete affordance, when available
└─ ControlBar                 // bottom: New Game · Restart · Undo · Hint
```

- `GameBoardView` reads `@Environment(GameSession.self)` (engine) and owns `@State private var drag: DragState?` plus `@State private var confirmingNewGame = false`.
- The stock is presented in the HUD's right zone as a **face-down deck** whose stack depth is the number of deals still available; it is itself the deal control (tap = deal). The ControlBar carries no deal button.
- HUD zone sizing is a pure value (`HUDLayout`), computed from the container width so the eight slots and the deck always fit beside the centred stats.

## 5. Responsive Layout Model

Layout is a **pure value** (`BoardLayout`) computed from container size + per-column card counts, so it is unit-testable with no SwiftUI.

```swift
struct BoardLayout {
    let cardSize: CGSize            // uniform; derived from width and card aspect ratio
    let columnGutter: CGFloat
    let faceDownPeek: CGFloat       // vertical offset between stacked face-down cards
    let faceUpPeek: CGFloat         // larger offset for face-up cards (readable rank/suit)
    func origin(column: Int, cardIndex: Int, in column: [Card]) -> CGPoint
    func columnHeight(cardCount: Int, faceUpCount: Int) -> CGFloat
}
```

Rules:
- **Card width** = `(containerWidth − 11·gutter) / 10`, clamped to a sensible min/max. **Card height** = width × deck aspect ratio (≈ 3.5/2.5; final value pinned once the CC0 deck is chosen).
- **Fanning:** face-down cards use a small `faceDownPeek`; face-up cards a larger `faceUpPeek` so rank+suit corners stay visible.
- **Vertical fit (no scroll):** compute each column's natural height; if the tallest exceeds available tableau height, apply a single global **peek compression factor** so the longest column fits. Peeks have hard minimums; if even minimum peeks overflow (pathological long column in landscape), the tableau region — and only that region — becomes vertically scrollable as a fallback. Prefer compression to scrolling.
- **Orientation:** portrait maximizes vertical fan room; landscape has wider columns but shorter height → compression engages sooner. Layout recomputes on `GeometryReader` size change; no separate code paths beyond the shared formula.
- Respect safe-area insets (notch / home indicator); HUD and ControlBar sit outside the tableau region.

## 6. Input & Gestures

### 6.1 Tap vs. drag disambiguation
A single `DragGesture(minimumDistance: k)` per movable card region:
- Translation `< k` on end → **tap** → `session.tap(column:index:)` (engine resolves auto-move, §7 of engine spec).
- Translation `≥ k` → **drag** (§6.2).

Only face-up cards that head a valid movable run are interactive; tapping/dragging a face-down card or a non-run card is inert (no feedback — US-4).

### 6.2 Drag-and-drop
1. **Pick up:** on drag begin over card at `(column, index)`, if `index...top` is a valid movable run (engine `Rules.topRun`/validation), capture it into `DragState { sourceColumn, indexRange, cards, touchOffset }`; hide those cards in place; render them in the `DragLayer` overlay following the touch.
2. **Track:** the dragged run follows the finger in a global coordinate space.
3. **Hit-test destination:** each `ColumnView` publishes its frame via a `PreferenceKey` frame registry (`[Int: CGRect]` in the board's coordinate space). On drag end, find the column whose rect contains the drop point.
4. **Commit or snap back:** call `session.move(from:index:to:)`. If it returns `true`, the engine state changed and [`animations`](./animations.md) glides cards to their new home; if `false` (illegal target or no target hit), the run snaps back to its origin with no state change and no error.

### 6.3 Controls
- **Deal:** tap the HUD deck (`DeckIndicator`) → `session.deal()`. The deck is greyed **only when the stock is spent** (`dealsRemaining == 0`); while cards remain it stays live even though the engine refuses to deal onto an empty column. A refused deal **flashes every empty column red** (~0.9s, `BoardInteraction.blockedColumns`) so the block is explained rather than presented as a dead control.
- **Undo:** `session.undo()`; disabled at game start.
- **Hint:** text button; starts the hint cycle owned by [`hints-and-autocomplete`](./hints-and-autocomplete.md). While cycling, any tap anywhere cancels.
- **New Game:** if a game is in progress (any move made and not won), present a confirmation dialog before `session.newGame(...)`; otherwise start immediately. Draws a **different** deal.
- **Restart:** confirmation dialog, then `session.restart()` — replays the **same** deal from the start, resetting score, counters, undo history, and timer.
- **Finish Game:** see [`hints-and-autocomplete`](./hints-and-autocomplete.md) §5; shown only while the board is mechanically completable and unwon.

## 7. HUD

- **Score:** `session.displayScore` (already floored at 0). Updates reactively via `@Observable`.
- **Timer:** MM:SS from `session.state.elapsed`, ticking once per second **only while running**. Driven by a UI-side `TimelineView(.periodic)` or a 1 Hz timer that reads engine elapsed; the engine remains the source of truth for accumulated time (§11 engine spec). Pauses with the engine.
- **Completed sets (left):** one card-shaped slot per King→Ace run, eight total, filled left-to-right from `board.completedRuns` in completion order; a filled slot shows that run's suit pip, an empty one a dashed outline. Replaces the former `Sets` text stat. The slots are **fanned at a 0.65 step** (`HUDLayout.slotOverlapStep`), so eight occupy 5.55 card widths rather than 8 and each card is markedly larger than in a side-by-side row. The step also sets how much of each layered slot stays visible: larger leaves more room around the suit pip but widens the fan and shrinks every card, and 0.65 keeps roughly a tenth of a card width of padding on either side of the pip. The **first** slot sits on top and is fully visible; each later slot is layered underneath the one before it, peeking out to the right. So every slot after the first shows only its right half, and the pip is centred in whatever strip is visible. Each slot is **masked to that visible strip**, i.e. drawn as if the slot in front of it were opaque. Filled slots look identical either way — the card in front already covers the rest — but without it the empty outlines, having no fill, all paint in full and cross each other into a thicket of dashes.
- **Deck (right):** a **single card back at a fixed size**, whatever the count, with `board.dealsRemaining` (0–5) on a numeric badge. The deck deliberately does not grow or shrink with the stock: the badge already carries the number, and a fixed footprint means the bar never reflows. An empty stock shows the outline alone. Dimmed and inert only when the stock is spent — see §6.3 for the empty-column case.
- **Menu:** icon-only chevron at the far left, ahead of the slots.

## 8. Lifecycle & Pause

- Observe `@Environment(\.scenePhase)`: `.active` → `session.resume()`; `.inactive`/`.background` → `session.pause()`.
- Opening any modal/menu (new-game confirmation, navigation to High Scores) calls `session.pause()`; dismissal calls `session.resume()`.
- The board itself holds no timer state — pause/resume is delegated to the engine so elapsed time stays authoritative and persistable.

## 9. Card Art Abstraction

- `protocol CardImageProvider { func face(_ card: Card) -> Image; func back() -> Image }`.
- v1 implementation loads the vetted CC0 SVG deck (PRD action item) as vector assets scaling cleanly across sizes; the single fixed card back; no theming.
- Views depend only on the protocol so art can be swapped without touching layout/gesture code, and previews can inject a placeholder deck.

## 10. Architecture & Concurrency

- `@MainActor` SwiftUI views bind to the `@MainActor @Observable GameSession`.
- `BoardLayout` and the frame registry are pure/value; no shared mutable state.
- Card identity for move animations comes from `Card.id` (stable) via `matchedGeometryEffect` in a namespace owned by `GameBoardView` (see [`animations`](./animations.md)).

## 11. Acceptance Criteria

- [ ] All 10 columns, HUD, and controls are visible without whole-screen scrolling on the smallest supported iPhone in both orientations.
- [ ] A long column compresses peeks to fit; only if minimum peeks overflow does the tableau region scroll.
- [ ] `BoardLayout` unit tests: card size, peeks, and column heights are correct for representative container sizes and column counts (no SwiftUI needed).
- [ ] Tap under threshold routes to `session.tap`; movement at/over threshold initiates a drag.
- [ ] Dragging a valid run and dropping on a legal column calls `session.move` and the move commits; dropping on an illegal/empty target snaps back with no state change and no error.
- [ ] Face-down and non-run cards are inert.
- [x] Deal indicator triggers `session.deal()`; it is greyed only when the stock is spent, and a deal refused by an empty column flashes that column red.
- [ ] Undo is disabled at game start and enabled after any move.
- [ ] New Game mid-play shows a confirmation; on a fresh/won board it starts immediately.
- [ ] Score shows floored value; timer shows MM:SS and ticks only while running.
- [ ] Backgrounding or opening a menu pauses the timer; returning resumes it.
- [x] No invalid-move feedback anywhere, with one deliberate exception: a deal blocked by an empty column flashes that column (§6.3). Rejected *moves* stay silent.

## 12. Open Questions / Action Items

- **AI-1:** Pin card aspect ratio and min/max card width once the CC0 deck is chosen (PRD action item).
- **AI-2:** Confirm drag `minimumDistance` threshold and touch-offset feel on device.
- ~~**AI-3:** Decide stock visual~~ — **resolved**: face-down deck graphic in the HUD's right zone, stack depth = deals remaining, tap to deal.

## 13. PRD Traceability

| PRD section | Covered by |
|---|---|
| Input & Interaction (single-tap, drag, no feedback) | §6 |
| Screens → Game Board | §4, §7 |
| Visual Assets (vector deck, fixed back, no theming) | §9 |
| Platform & Scope (iPhone, both orientations, all sizes) | §5 |
| Game State & Lifecycle (new-game confirmation, pause) | §6.3, §8 |
| Timing (live MM:SS, pause/resume) | §7, §8 |
