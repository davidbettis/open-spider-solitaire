import Foundation
import Testing
@testable import OpenSpiderSolitaire

struct AppInfoTests {

    // MARK: - The website link

    @Test("The homepage URL literal parses")
    func homepageParses() throws {
        // The whole reason `homepage` is optional instead of force-unwrapped:
        // a typo drops the Settings row silently, so this is what catches it.
        let url = try #require(AppInfo.homepage)
        #expect(url.absoluteString == "https://davidbettis.com/open-spider-solitaire/")
        #expect(url.scheme == "https")
    }

    // MARK: - The version row

    @Test("A build number that repeats the version is not shown twice")
    func buildMatchingVersionIsOmitted() {
        #expect(AppInfo.versionString(short: "1.0.0", build: "1.0.0") == "1.0.0")
    }

    @Test("A build number that has moved past the version is shown")
    func differingBuildIsShown() {
        #expect(AppInfo.versionString(short: "1.0.0", build: "7") == "1.0.0 (7)")
    }

    @Test("Either half alone still produces a usable line")
    func oneHalfMissing() {
        #expect(AppInfo.versionString(short: "1.2", build: nil) == "1.2")
        #expect(AppInfo.versionString(short: nil, build: "42") == "42")
    }

    @Test("Missing and blank keys both fall back rather than showing an empty row")
    func missingOrBlank() {
        #expect(AppInfo.versionString(short: nil, build: nil) == "—")
        #expect(AppInfo.versionString(short: "", build: "  ") == "—")
        #expect(AppInfo.versionString(short: "1.0.0", build: "") == "1.0.0")
    }

    @Test("The real bundle reports a version, not the fallback")
    func realBundle() {
        // Hosted in the app, so `.main` is the app bundle and this is what the
        // About section will actually show. Deliberately not asserting the
        // literal, which would fail on every version bump.
        let version = AppInfo.versionString()
        #expect(version != "—")
        #expect(!version.isEmpty)
    }
}
