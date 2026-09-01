import SwiftUI

/// The app's surfaces, in system semantic colours so every screen follows the
/// platform (and the user's appearance setting) rather than a bespoke theme.
///
/// **Cards are the deliberate exception.** A playing card is white with red and
/// black pips; making its face adaptive would put black pips on a black card in
/// dark mode. So `CardFace` stays white and the surfaces around it are chosen to
/// contrast with white in both appearances.
enum Palette {
    /// Plain screens with no content needing contrast — the title screen.
    static let screen = Color(.systemBackground)
    /// Behind the tableau and the score table: a shade off `screen`, so white
    /// cards and rows read against it in light mode and pop in dark.
    static let table = Color(.systemGroupedBackground)
    /// The HUD and control bars, and grouped panels.
    static let bar = Color(.secondarySystemGroupedBackground)
    /// The playing field: the strip behind each column **and** the tableau
    /// region as a whole. Both use this one opaque colour, so the gutters
    /// between columns do not show through as lighter stripes.
    static let columnStrip = Color(.systemGray5)
    /// Empty set slot and spent-stock outlines.
    static let placeholder = Color(.tertiaryLabel)
}
