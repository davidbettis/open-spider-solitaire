# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Project: OpenSpiderSolitaire

## Quick Reference
- **Platform**: iOS 17+ — iPhone is the shipping target (`TARGETED_DEVICE_FAMILY = 1`); iPad is planned for a later version
- **Orientation**: portrait and landscape (no upside-down while iPhone-only)
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

## Device Support: iPhone Now, iPad Later
**iPhone is the primary and only shipping target** (`TARGETED_DEVICE_FAMILY = 1`).
**iPad is a planned secondary target, deferred to a later version** — it is not cut,
just not built yet.

Until that version is scheduled:
- Build and verify for iPhone. The board UI is designed and verified at iPhone sizes;
  there is no iPad design to build against yet, so an iPad build would ship a stretched
  iPhone layout.
- Do not add iPad layouts, `~ipad` Info.plist keys, or iPad-only APIs (Slide Over,
  Stage Manager, pointer/hover) ahead of that work.
- **Do** keep new UI layout-driven rather than hardcoded to iPhone geometry — prefer
  size classes and the existing `BoardLayout` / `HUDLayout` sizing math over magic
  numbers, so the later iPad pass is a layout problem and not a rewrite.

### What flipping on iPad will require
1. Set `TARGETED_DEVICE_FAMILY: "1,2"` on **each target's** `settings.base` in
   `project.yml` (see the trap below), then `xcodegen generate`.
2. Add the fourth orientation: a universal build is **rejected at App Store validation**
   unless `UISupportedInterfaceOrientations` lists all four, including
   `UIInterfaceOrientationPortraitUpsideDown`, for iPad multitasking. The current list
   is portrait + both landscapes, which is valid only while the app is iPhone-only.
3. Design an actual iPad board layout before enabling any of the above.

**Setting the device family is a trap.** XcodeGen writes its own defaults at the *target*
level, and those override the project-level `settings.base`. `TARGETED_DEVICE_FAMILY`
must therefore be declared on **each target's** `settings.base` — set only at the project
level, it is silently overridden with `"1,2"` and the app ships as universal by accident
(this is exactly how the App Store validation rejection above was first hit). After
changing it, verify the built product, not the YAML:
`plutil -p <built .app>/Info.plist | grep -A2 UIDeviceFamily`.

(An inert `AppIcon76x76@2x~ipad.png` / `CFBundleIcons~ipad` already appears in the bundle;
that comes from the modern single-size `"universal"` app icon and is harmless — device
support is determined by `UIDeviceFamily`, not icon idioms.)

## macOS Support
While the app is iPhone-only it runs on Apple Silicon Macs as **"Designed for iPhone"**
(not Mac Catalyst or native macOS). It will present as "Designed for iPad" once the iPad
target above is enabled; either way, the rules are the same:
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
