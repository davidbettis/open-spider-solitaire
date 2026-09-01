import Foundation

/// The player's preferences. This is the settings model the persistence spec
/// (§5) reserved a slot for in ``DurableData``.
struct AppSettings: Hashable, Codable, Sendable {
    /// Difficulty for the next game. Chosen in Settings rather than on the
    /// title screen, so Start Game is a single tap.
    var suitMode: SuitMode = .one
    /// Which appearance the app forces, if any.
    var appearance: Appearance = .system
}

/// Appearance override. `system` follows the device setting, which is the
/// default and what `Palette` is designed around.
enum Appearance: String, Codable, Sendable, Hashable, CaseIterable {
    case system
    case light
    case dark
}
