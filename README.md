# Open Spider Solitaire

A Spider Solitaire game for iPhone and iPad that works entirely offline.

## Principles

- **Free.** Open Spider Solitaire is free to use with no ads, subscriptions, or in-app purchases.
- **Open.** The source code is open, under the MIT license. It is one Swift app target with no third-party dependencies, and a spec in `docs/` for every feature in it.
- **Offline.** The app makes no network connections of any kind. It contains no networking code, no analytics libraries, and no advertising SDKs, and it behaves identically in airplane mode.
- **Your data.** Your games and scores live in a sandboxed folder on your device. There are no accounts, no cloud services we operate, no iCloud sync, and no way for us to see anything you do.

## Features

- **Three difficulties:** 1 suit (easy), 2 suits (medium), and 4 suits (hard), each with its own leaderboard.
- **Scoring.** Start at 500 points, lose one per move and per undo, gain 100 for each completed King-to-Ace run.
- **Unlimited undo** back to the first move.
- **Free hints.** Step through every legal move on the board. Hints cost time but no points.
- **Auto-complete** when only mechanical moves remain, at no point cost.
- **Resume.** Quit mid-game and the board, score, and clock come back exactly as you left them.
- **High scores** per difficulty, ranked by score and then by time, with a time to beat.
- **Light and dark**, following your device or forced either way in Settings.
- **iPhone and iPad**, in portrait and landscape. There is no separate iPad
  screen: the board is sized from the space it is given, and on an iPad the
  cards, the bars, and the fan down each column all scale up with it. That
  follows the *window*, so an iPad in Split View or a small window gets the
  compact layout rather than the device's.

## Game rules

Standard Spider Solitaire. Two decks, 104 cards, dealt into ten tableau columns, with the
remaining 50 cards forming five stock deals.

- Build descending sequences within a column. Any card may be placed on a card one rank
  higher, whatever its suit.
- Only an ordered **same-suit** sequence moves as a group.
- A complete King-to-Ace same-suit run clears automatically.
- A stock deal puts one card on every column, and is not allowed while any column is empty.
- Any card or sequence may move onto an empty column.
- Clear all eight runs to win.

Deals are randomly shuffled and are **not** guaranteed to be winnable. Filtering deals through
a solver so every one is solvable is planned but not yet built.

## Requirements

- iPhone or iPad running iOS 17 or later.
- Also runs on Apple Silicon Macs as "Designed for iPad".

## Building

The Xcode project is generated and is not checked in. [XcodeGen](https://github.com/yonaskolb/XcodeGen)
builds it from `project.yml`, which is the source of truth for every build setting.

```sh
brew install xcodegen
xcodegen generate
open OpenSpiderSolitaire.xcodeproj
```

Because the project is regenerated, **changing a setting in Xcode's UI will not stick.** Edit
`project.yml` and run `xcodegen generate` again.

To build to a device you need your own signing team. Create `Config/Signing.local.xcconfig`,
which is gitignored, containing one line:

```
DEVELOPMENT_TEAM = YOURTEAMID
```

Simulator builds work without it. `Config/Signing.xcconfig` explains how to find your team ID.

Tests run on the simulator, from Xcode with Cmd-U or from the command line:

```sh
xcodebuild -project OpenSpiderSolitaire.xcodeproj -scheme OpenSpiderSolitaire \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Substitute a simulator you actually have. `xcodebuild` resolves a destination against your
newest installed runtime, so naming a device that only exists on an older one fails with
"no available devices matched" even though the simulator is right there. `xcrun simctl list
devices available` lists what you have.

## Project layout

```
docs/            PRD and a spec per feature
project.yml      XcodeGen spec, the source of truth for the project
src/OpenSpiderSolitaire/
  App/           Entry point and root navigation
  Core/          Game engine, scoring, deals, persistence, settings, high scores
  Features/      Game board, menu, settings, high scores (SwiftUI + @Observable)
  Resources/     Asset catalog
src/OpenSpiderSolitaireTests/
```

`docs/PRD.md` states the product decisions, and `docs/specs/` holds one spec per feature with
the acceptance criteria each was built against.

## Privacy

Open Spider Solitaire collects no data at all. See [the privacy policy](docs/PRIVACY.md).

## License

MIT. See [LICENSE](LICENSE).
