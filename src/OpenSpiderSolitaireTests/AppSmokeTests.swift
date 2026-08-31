import Testing
@testable import OpenSpiderSolitaire

/// Scaffolding smoke test — proves the test target builds and links against the
/// app module. Replaced by real engine tests (per `docs/specs/game-engine.md`)
/// in the next phase.
struct AppSmokeTests {
    @Test func appModuleLinks() {
        // Reaching a symbol from the app module confirms the target wiring.
        _ = Route.game
        #expect(Bool(true))
    }
}
