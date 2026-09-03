# Spider Solitaire — iOS App Specification

## Overview

A native iOS (iPhone and iPad) Spider Solitaire game with configurable difficulty (1, 2, or 4 suits), scoring, move undo, timing, and persistent high scores. Fully offline: no ads, no in-app purchases, no network calls, no accounts.

## Game Rules

Standard Spider Solitaire:

- Two decks (104 cards) dealt into 10 tableau columns (4 columns of 6 cards, 6 columns of 5 cards); top card of each column face-up, rest face-down.
- Remaining 50 cards form 5 stock deals of 10 cards each.
- Build descending sequences within columns; a card may be placed on any card one rank higher regardless of suit.
- Only ordered **same-suit** sequences move as a group. A complete King-to-Ace same-suit run is automatically cleared from the tableau.
- Stock deals one card to every column; not allowed while any column is empty.
- Any card or sequence may be moved onto an empty column.
- Game is won when all 8 runs are cleared.
- **Deals are guaranteed solvable** (see Deal Generation).

## Difficulty (Suit Selection)

Selected before starting a game:

| Mode | Suits used | Difficulty |
|------|-----------|-----------|
| 1 suit | Spades only | Easy |
| 2 suits | Spades, Hearts | Medium |
| 4 suits | All four | Hard |

Each mode uses two full decks restricted to the selected suits: 1-suit = 8 copies of one suit's 13 ranks; 2-suit = 4 copies each of two suits; 4-suit = 2 copies each of all four suits.

## Deal Generation

- **v1:** each deal is a **uniformly-shuffled** standard layout — 54 tableau cards with the 44 non-top cards face-down, 50 in stock. Dealt at runtime by shuffling the mode's 104-card multiset. **Not guaranteed winnable in v1.**
- RNG is purely random (not seeded).
- **Guaranteed-solvable deals are deferred to a later phase.** The intended approach is an **offline pre-generated pool of solvable deals** bundled with the app: deal random layouts, filter with a bounded solver, keep the winnable ones, and select at runtime for free (O(1), zero construction cost). The runtime `DealProvider` seam makes swapping the random provider for a pool-backed one a drop-in change with no other code changes.
- *Rationale for deferral: guaranteed-solvable deals need a competent Spider solver to filter the pool, and that solver is the genuinely hard part. Two runtime alternatives were also set aside — **reverse-construction** (guarantees solvability cheaply but yields no face-down obstacles, so boards play open/easy) and **runtime generate-and-verify** (too costly for 4-suit, which is solvable too infrequently). Shipping random deals now unblocks the rest of the app; the offline pool is the planned path to winnability.*

## Scoring

- Start each game with **500 points**.
- **−1 point** per move.
- **−1 point** per undo action.
- **+100 points** for each completed same-suit run (King down to Ace) cleared from the tableau.
- Internally the score may go negative; **display is floored at 0** (a −12 internal score shows as 0).
- Saved leaderboard values use the **floored (≥0) score**, for consistency with display.
- **Hints are free** (no point cost).
- **No point farming:** undoing a run-clear reverses the +100; re-clearing that same run re-awards +100 only once net. Implemented by tracking cleared-run identity so a clear/undo/re-clear cycle nets a single +100.

### What counts as a "move" (−1 each)

- A tableau-to-tableau relocation of a single card.
- A tableau-to-tableau relocation of a valid same-suit sequence (one move, not per-card).
- A stock deal (**one move for the whole row of 10**, not ten).

### What is NOT a move

- Automatic run-clears.
- Automatic card flips (revealing a face-down card).
- Auto-complete moves.
- Hints.

## Timing

- Timer starts on the first move of a game, runs until the game is won.
- Displayed live during play (MM:SS).
- **Timer pauses** when the app is backgrounded or a menu is open, and resumes on return.
- On a win, final time is recorded as a potential "time to beat."
- Only winning games record a time; lost or abandoned games record nothing.
- **Resumed games:** elapsed time persists across sessions and app restarts.

## High Scores

Persisted locally, tracked **separately per suit mode**, as a **top-N leaderboard** (recommend N = 10).

- Each leaderboard entry is a single completed game.
- **Score and time are coupled:** one entry holds both the score and the time from the same winning game.
- **Ranking:** score primary (higher is better), time secondary (faster breaks ties).
- **Time to beat** = the time on the current top-ranked entry for that mode.
- User can **reset/clear** all high scores (with confirmation).
- Optional stats: games won, win rate.
- *Because entries are coupled and ranked score-then-time, the all-time fastest time for a mode may not surface if a higher-scoring game was slower. This is accepted.*

## Undo

- Unlimited undo back to the game's start.
- Each undo reverses exactly one prior action (single move, sequence move, or stock deal).
- Each undo costs **−1 point**.
- **Undo jumps instantly** (no reverse animation).
- Undoing a stock deal returns the dealt cards to the stock.
- Undoing a cleared run restores it to the tableau and reverses the +100.
- **No redo.**

## Hints

- Triggered by a hint control.
- Shows possible moves by animating a candidate card to each legal destination, one after another.
- Tapping anywhere cancels the hint cycle.
- **Free** — no point penalty. (Runs while the timer is active, so hints cost real time but no points; intended.)

## Auto-Complete

- Offered when only trivial moves remain (all cards face-up and the remaining board is mechanically solvable without choices).
- Finishes the game automatically.
- Auto-complete moves **do not cost points**.

## Input & Interaction

- **Single-tap auto-move:** a single tap on a card moves it to a valid destination automatically (if one exists).
- **Ambiguous single-taps** (more than one legal destination) resolve by priority order: same-suit sequence continuation → any legal descending placement → empty column.
- **Drag-and-drop:** available for manual destination control when the player wants to choose a specific target.
- Tap-to-select-then-tap-destination is not used (replaced by single-tap auto-move + drag).
- **No invalid-move feedback** (invalid moves simply don't complete).

## Visual Assets

- **Card faces/backs:** an identity, open-source, public-domain SVG deck. *Action item: select and vet a specific public-domain SVG deck; confirm license (e.g., CC0) and record attribution if any.*
- **Format:** vector (SVG), scaling cleanly across all iPhone and iPad sizes.
- **Card back:** single fixed design.
- **No theming** at launch (no light/dark variants; fixed table/felt and accent colors).
- **1-suit color:** no visual aid to distinguish sequences; all one color as normal.

## Animations & Feedback

- **Card movement:** animated glide.
- **Deal:** animated (initial deal and each stock deal).
- **Card flip:** animated when a face-down card is revealed.
- **Run-clear:** animated celebration when a King-to-Ace run clears.
- **Win:** both the classic cascade animation and a summary screen.
- **Undo:** instant, no animation.
- **No haptics, no sound.**
- **No invalid-move feedback.**

## Game State & Lifecycle

- **Resume in progress:** a mid-game exit (quit, call, backgrounding) preserves full game state — tableau, stock, score, undo stack, and elapsed time — and restores it on return.
- **New-game confirmation:** starting a new game while one is in progress prompts for confirmation.

## Accessibility

None at launch: no VoiceOver support, no Dynamic Type scaling, no colorblind aids, no Reduce Motion handling, no enlarged tap targets. *Note: Reduce Motion is low-effort given the animation-heavy design and worth reconsidering.*

## Platform & Scope

- **Universal: iPhone and iPad.**
- **Orientation:** portrait and landscape on iPhone; all four on iPad, which App
  Store validation requires of a universal app so multitasking can hand it any
  of them.
- **Device range:** all current iPhone and iPad sizes, including iPad
  multitasking and iPadOS windowing, where the app may be given any window size.
- **One layout, two scales.** There is no separate iPad screen. The board is
  derived from its container and already scaled; the chrome around it — the HUD,
  the control bar, the title screen — is the iPhone design multiplied, and the
  tableau fans further down the column when there is room to. Both follow the
  **size classes**, so an iPad in a narrow Split View pane or a small window
  correctly gets the compact design rather than the device's.
- **Minimum iOS:** 17+.
- **App name, icon, App Store metadata:** placeholders for now.

## Constraints

- No advertisements.
- No in-app purchases or paid tiers.
- Fully functional offline; no network, no accounts, no analytics/tracking.
- **No iCloud sync** — local-only persistence.

## Persistence & Schema Versioning

- **Persistence:** `UserDefaults` (or a small `Codable` local store) for high scores and settings; `Codable` game-state snapshot for resume-in-progress.
- **Schema versioning:** the persisted save format (high scores and in-progress game state) includes a **version field**. On launch, a version mismatch triggers a migration path; unmigratable data fails gracefully without corrupting the app.

## Suggested Technical Stack

- **Language:** Swift.
- **UI:** SwiftUI, or UIKit if drag-and-drop animation control proves easier there.
- **State:** an observable game-state model holding tableau, stock, score, timer, and undo stack.
- **Undo stack:** in-memory list of reversible action records, cleared on new game.

## Screens

1. **Main Menu** — New Game, suit-mode selection, High Scores, Reset Scores.
2. **Game Board** — tableau, stock, live score (floored), live timer, undo, hint, new-game control.
3. **High Scores** — top-N leaderboard per suit mode (score + coupled time).
4. **Win Screen** — cascade animation plus summary (final score, final time, records beaten).

## Remaining Action Items

- Select and license-vet a specific public-domain SVG card deck.
- Finalize app name, icon, and App Store metadata (currently placeholders).
