import Foundation

/// The app's identity as shipped: what Settings' About section reports.
///
/// The version comes from the built bundle rather than from a constant in
/// code, so it follows `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in
/// `project.yml` and cannot drift from what was actually built.
enum AppInfo {
    /// The project's page.
    ///
    /// Optional rather than force-unwrapped: a typo here should drop the row,
    /// not trap. `AppInfoTests` asserts it parses, which is what actually
    /// catches the typo — before it ships, rather than under a user's thumb.
    static let homepage = URL(string: "https://davidbettis.com/open-spider-solitaire/")

    /// What the Version row shows, e.g. `1.0.0` or `1.0.0 (7)`.
    static func versionString(bundle: Bundle = .main) -> String {
        versionString(
            short: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    /// Composes the two bundle strings into one line.
    ///
    /// The build number is shown only when it says something the version does
    /// not. `project.yml` currently sets `MARKETING_VERSION` and
    /// `CURRENT_PROJECT_VERSION` to the same `1.0.0`, and a row reading
    /// "1.0.0 (1.0.0)" looks like a bug rather than a build number; once builds
    /// start incrementing independently, the suffix appears on its own.
    ///
    /// Split out from ``versionString(bundle:)`` because this rule is the part
    /// worth testing, and a `Bundle` with arbitrary keys cannot be built.
    static func versionString(short: String?, build: String?) -> String {
        switch (nonEmpty(short), nonEmpty(build)) {
        case (nil, nil): return "—"
        case let (short?, nil): return short
        case let (nil, build?): return build
        case let (short?, build?): return short == build ? short : "\(short) (\(build))"
        }
    }

    /// Treats a missing key and a present-but-blank one as the same thing;
    /// `GENERATE_INFOPLIST_FILE` can emit either.
    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }
}
