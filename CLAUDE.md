# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Project: OpenSpiderSolitaire

## Quick Reference
- **Platform**: iOS 17+ — universal, iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`)
- **Orientation**: iPhone portrait + landscape; iPad all four (required for a universal bundle)
- **Language**: Swift 6.0
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with @Observable
- **Minimum Deployment**: iOS 17.0
- **Package Manager**: Swift Package Manager

## XcodeBuildMCP Integration
**IMPORTANT**: This project uses XcodeBuildMCP for all Xcode operations.
- Build: `mcp__xcodebuildmcp__build_sim_name_proj`
- Test: `mcp__xcodebuildmcp__test_sim_name_proj`
- Clean: `mcp__xcodebuildmcp__clean`

## Project Structure

src/OpenSpiderSolitaire
├── App/ # App entry point, App delegate
├── Features/ # Feature modules
│ ├── [FeatureName]/ │
│ ├── Views/ # SwiftUI views
│ │ ├── ViewModels/ # @Observable classes
│ │ └── Models/ # Data models
├── Core/ # Shared utilities
│ ├── Extensions/
│ ├── Services/
│ └── Networking/
├── Resources/ # Assets, Localizations

src/OpenSpiderSolitaireTests - flat folder full of tests

src/OpenSpiderSolitaireUITests - flat folder full of tests

## Coding Standards

### Swift Style
- Use Swift 6 strict concurrency
- Prefer `@Observable` over `ObservableObject`
- Use `async/await` for all async operations
- Follow Apple's Swift API Design Guidelines
- Use `guard` for early exits
- Prefer value types (structs) over reference types (classes)

### SwiftUI Patterns
- Extract views when they exceed 100 lines
- Use `@State` for local view state only
- Use `@Environment` for dependency injection
- Prefer `NavigationStack` over deprecated `NavigationView`
- Use `@Bindable` for bindings to @Observable objects

### Navigation Pattern
```swift
// Use NavigationStack with type-safe routing
enum Route: Hashable {
    case detail(Item)
    case settings
}

NavigationStack(path: $router.path) {
    ContentView()
        .navigationDestination(for: Route.self) { route in
            // Handle routing
        }
}

## Error Handling
```
// Always use typed errors
enum AppError: LocalizedError {
    case networkError(underlying: Error)
    case validationError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error): return error.localizedDescription
        case .validationError(let msg): return msg
        }
    }
}
```

## Testing Requirements
- Unit tests for all ViewModels
- UI tests for critical user flows
- Use Swift Testing framework (@Test, #expect)
- Minimum 80% code coverage for business logic

## Device Support: Universal (iPhone + iPad)

The app ships **universal** (`TARGETED_DEVICE_FAMILY = "1,2"`). iPhone remains the
design baseline; iPad is the same app scaled, not a second layout.

**Setting the device family is a trap.** XcodeGen writes its own defaults at the
*target* level, and those override the project-level `settings.base`. So
`TARGETED_DEVICE_FAMILY` is declared on **each target's** `settings.base` even
though the value now happens to match XcodeGen's default — it stays spelled out
so it is a decision and not a coincidence of whatever XcodeGen defaults to next.
(This was first hit in the other direction: `"1"` set only at the project level
was silently overridden with `"1,2"` and the app shipped universal by accident,
which App Store validation rejected.) After changing it, verify the built
product, not the YAML:
`plutil -p <built .app>/Info.plist | grep -A3 UIDeviceFamily`.

**Orientations are per idiom, and iPad's list must be exhaustive.** A universal
bundle is **rejected at App Store validation** unless iPad supports all four,
including `UIInterfaceOrientationPortraitUpsideDown`, for multitasking. So
`project.yml` sets `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone`
(portrait + both landscapes) and `..._iPad` (all four), and deliberately does
**not** set the generic `INFOPLIST_KEY_UISupportedInterfaceOrientations`.

### How the two idioms differ
There is no iPad-specific screen, and nothing is gated on `UIDevice`. Two knobs
carry the whole difference, both driven by **size classes** and both applied only
when the container is `.regular` in *both* axes:

- **`Core/Layout/Chrome.swift`** — injected into the environment once, in
  `RootView`, and read by the bars and the menu/settings/high-score screens. It
  multiplies the iPhone-tuned point metrics (`chrome.scale`) and picks the larger
  text style (`chrome.pick(phone:pad:)`). The board needed none of this:
  `BoardLayout` already derives every card from its container.
- **`BoardLayout.Spread`** — `.roomy` fans the tableau further down the column so
  the board is not stranded in a band across the top of an iPad. See
  `docs/specs/game-board-ui.md` §5 for why it is measured against a fixed nominal
  column rather than the live board.

Why size classes and not width: an iPhone 17 Pro Max in landscape is 956pt wide,
wider than an iPad mini in portrait at 744pt, but only 440pt tall — width alone
cannot tell the idioms apart, and the pair can. It also means an iPad in Slide
Over, in a narrow Split View pane, or in a small iPadOS 26 window correctly gets
the compact design; a pane is regular only from roughly 639pt.

**Keep new UI layout-driven.** Prefer size classes and the existing
`BoardLayout` / `HUDLayout` / `Chrome` math over magic numbers; a point value
that was measured against an iPhone belongs in `Chrome` as `base * chrome.scale`,
not inline.

**Verifying iPad layouts.** The simulator cannot be rotated from this environment
(no assistive access for `osascript`, and `simctl` has no rotate). Landscape was
checked by temporarily rendering the root view into a fixed 1366×1024 frame,
scaled to fit a portrait simulator — see `simulator-verification` in memory for
that pattern and how to revert it.

## macOS Support
Now that the app is universal it runs on Apple Silicon Macs as **"Designed for
iPad"** (not Mac Catalyst or native macOS). The rules are unchanged:
- `#if os(macOS)` is **always false** — do NOT use it for Mac-specific behavior
- Use `ProcessInfo.processInfo.isiOSAppOnMac` for runtime Mac detection instead
- UIKit types like `UIImage` are available on Mac (no need for `#if canImport(UIKit)` guards)

## DO NOT
- Write UITests during scaffolding phase
- Use deprecated APIs (UIKit when SwiftUI suffices)
- Create massive monolithic views
- Use force unwrapping (!) without justification
- Ignore Swift 6 concurrency warnings

## Planning Workflow

When starting new features:
- Read the PRD from docs/PRD.md
- Create feature spec in docs/specs/[feature-name].md
- Use ultrathink for architectural decisions
- Use Plan Mode (Shift+Tab) for implementation strategy
- Implement incrementally with tests
