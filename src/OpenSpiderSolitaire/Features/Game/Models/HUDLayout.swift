import CoreGraphics

/// Pure, testable sizing math for the HUD's card-shaped zones, mirroring
/// ``BoardLayout``: the eight completed-set slots (left) and the deck (right)
/// share whatever width the centred score/timer and the menu chevron leave, so
/// they always fit on the narrowest supported iPhone without truncating.
///
/// Every constant here is an **iPhone** measurement, multiplied by ``Chrome``'s
/// scale. The bar is the one part of the board screen that is not derived from
/// its container — a HUD that grew with the window would swallow an iPad's
/// height — so it is pinned to the idiom instead.
struct HUDLayout: Equatable {
    /// One slot per King→Ace run; the game is won at eight.
    static let slotCount = 8

    /// Height the bar gives its card-shaped zones on iPhone. Lives here, not on
    /// the view, so the layout math and its tests cannot drift apart.
    static let phoneContentHeight: CGFloat = 45

    /// Width the centred stats, the menu chevron, and the bar padding claim
    /// before the card zones get their share, on iPhone. It scales with the
    /// chrome because everything inside it does: the stats step up a text
    /// style on iPad and the paddings are multiplied.
    static let phoneReservedWidth: CGFloat = 176
    /// Floor for the card zones, so a very narrow container degrades to small
    /// slots rather than to zero-width ones.
    static let phoneMinimumZoneWidth: CGFloat = 120

    /// How far each successive set slot advances, as a fraction of slot width,
    /// and therefore how much of each layered slot stays visible. Eight slots
    /// occupy `1 + 7 * step` card widths instead of 8.
    ///
    /// This trades two things off: a larger step leaves more room for the suit
    /// pip and its padding, but widens the fan and so shrinks every card. 0.65
    /// keeps a comfortable margin around the pip while staying far narrower
    /// than a side-by-side row.
    static let slotOverlapStep: CGFloat = 0.65
    private static let zoneGapRatio: CGFloat = 0.3 // slot fan → deck breathing room

    let slotSize: CGSize
    /// Horizontal advance between successive set slots (they overlap).
    let slotStep: CGFloat
    /// The height budget the card zones were fitted to, at this chrome scale.
    let contentHeight: CGFloat

    init(containerWidth: CGFloat, scale: CGFloat = 1) {
        let contentHeight = HUDLayout.phoneContentHeight * scale
        let reserved = HUDLayout.phoneReservedWidth * scale
        let minimumZoneWidth = HUDLayout.phoneMinimumZoneWidth * scale
        let flexible = max(minimumZoneWidth, containerWidth - reserved)

        // The overlapping slot fan, the deck's single card, and one gap
        // between them all come out of `flexible`, measured in slot widths.
        let slotFootprints = 1 + CGFloat(HUDLayout.slotCount - 1) * HUDLayout.slotOverlapStep
        let byWidth = flexible / (slotFootprints + 1 + HUDLayout.zoneGapRatio)
        let byHeight = max(1, contentHeight) / BoardLayout.aspectRatio

        let slotWidth = max(1, min(byWidth, byHeight))
        self.slotSize = CGSize(width: slotWidth, height: slotWidth * BoardLayout.aspectRatio)
        self.slotStep = slotWidth * HUDLayout.slotOverlapStep
        self.contentHeight = contentHeight
    }

    /// Height the bar reserves for its content, before its own padding. Static
    /// because the bar is framed before its width is known.
    static func barHeight(scale: CGFloat) -> CGFloat {
        phoneContentHeight * scale * BoardLayout.aspectRatio
    }

    /// Width the overlapping slot fan occupies: one full card plus each
    /// successive slot's advance.
    var slotsWidth: CGFloat {
        slotSize.width + CGFloat(HUDLayout.slotCount - 1) * slotStep
    }

    /// Width reserved for the deck: one card. It neither grows nor shrinks
    /// with the stock — the badge carries the count — so the bar never reflows.
    var deckWidth: CGFloat { slotSize.width }

    /// Total width the two card zones need; must stay within the flexible share.
    var cardZonesWidth: CGFloat { slotsWidth + deckWidth }
}
