import SwiftUI

/// How big the app's *chrome* is drawn: the HUD, the control bar, and the
/// furniture on the title and high-score screens.
///
/// The board needed nothing for iPad — ``BoardLayout`` already derives every
/// card from the container it is handed. The bars did: their heights, paddings,
/// and text styles were point values and type styles tuned against an iPhone,
/// so on an iPad they left a 45pt HUD sitting beside a 174pt card. This is the
/// one knob that fixes them, applied at the root and read from the environment.
///
/// **The signal is the size-class pair, not the raw width.** Width alone cannot
/// tell the two idioms apart: an iPhone 17 Pro Max in landscape is 956pt wide,
/// wider than an iPad mini in portrait at 744pt. But that phone is only 440pt
/// *tall*, so it needs the compact chrome, and the size classes say exactly
/// that — `.regular` horizontally, `.compact` vertically. Only a container
/// that is regular in **both** axes is an iPad with room to spare. An iPad in
/// Slide Over is compact-width and correctly falls back to `.phone`.
enum Chrome {
    case phone
    case pad

    init(horizontal: UserInterfaceSizeClass?, vertical: UserInterfaceSizeClass?) {
        self = (horizontal == .regular && vertical == .regular) ? .pad : .phone
    }

    /// Multiplier for the point-based chrome metrics, all of which were tuned
    /// on iPhone and are therefore expressed as `base * chrome.scale`.
    ///
    /// 1.8 is set by the HUD, the tightest constraint: it is what makes the
    /// bar's card zones read as siblings of the tableau's cards instead of as
    /// a row of thumbnails, while keeping the bar itself near a *smaller*
    /// share of the screen than it takes on a phone (~13% of an iPad's
    /// landscape height against ~20% of an iPhone's).
    var scale: CGFloat {
        switch self {
        case .phone: return 1
        case .pad: return 1.8
        }
    }

    /// Choose between an iPhone-tuned value and an iPad one.
    ///
    /// Text styles are picked this way rather than scaled: stepping
    /// `.subheadline` up to `.title3` keeps the label inside Dynamic Type,
    /// where multiplying a point size would opt it out.
    func pick<T>(phone: T, pad: T) -> T {
        switch self {
        case .phone: return phone
        case .pad: return pad
        }
    }
}

// MARK: - Environment

private struct ChromeKey: EnvironmentKey {
    /// Compact, so anything rendered outside the root (a preview, a snapshot)
    /// gets the phone design rather than a half-scaled one.
    static let defaultValue: Chrome = .phone
}

extension EnvironmentValues {
    /// Set once, at the root, from the window's size classes.
    var chrome: Chrome {
        get { self[ChromeKey.self] }
        set { self[ChromeKey.self] = newValue }
    }
}
