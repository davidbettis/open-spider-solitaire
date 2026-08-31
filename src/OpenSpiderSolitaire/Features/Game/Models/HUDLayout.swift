import CoreGraphics

/// Pure, testable sizing math for the HUD's card-shaped zones, mirroring
/// ``BoardLayout``: the eight completed-set slots (left) and the deck (right)
/// share whatever width the centred score/timer and the menu chevron leave, so
/// they always fit on the narrowest supported iPhone without truncating.
struct HUDLayout: Equatable {
    /// One slot per King→Ace run; the game is won at eight.
    static let slotCount = 8
    /// Deepest the deck ever stacks: a 50-card stock dealt 10 at a time.
    static let maxDeals = 5

    /// Width the centred stats, the menu chevron, and the bar padding claim
    /// before the card zones get their share.
    static let reservedWidth: CGFloat = 176
    /// Floor for the card zones, so a very narrow container degrades to small
    /// slots rather than to zero-width ones.
    static let minimumZoneWidth: CGFloat = 120

    private static let gapRatio: CGFloat = 0.16    // slot spacing / slot width
    private static let depthRatio: CGFloat = 0.12  // deck stack offset / slot width

    let slotSize: CGSize
    let slotSpacing: CGFloat
    /// Horizontal step between successive card backs in the deck stack.
    let deckOffsetStep: CGFloat

    init(containerWidth: CGFloat, contentHeight: CGFloat) {
        let flexible = max(HUDLayout.minimumZoneWidth, containerWidth - HUDLayout.reservedWidth)

        // Nine card footprints (eight slots + the deck), the gaps between them,
        // and the deck's depth offsets all come out of `flexible`.
        let footprints = CGFloat(HUDLayout.slotCount + 1)
        let gaps = footprints * HUDLayout.gapRatio
        let depth = CGFloat(HUDLayout.maxDeals - 1) * HUDLayout.depthRatio
        let byWidth = flexible / (footprints + gaps + depth)
        let byHeight = max(1, contentHeight) / BoardLayout.aspectRatio

        let slotWidth = max(1, min(byWidth, byHeight))
        self.slotSize = CGSize(width: slotWidth, height: slotWidth * BoardLayout.aspectRatio)
        self.slotSpacing = slotWidth * HUDLayout.gapRatio
        self.deckOffsetStep = slotWidth * HUDLayout.depthRatio
    }

    /// Width the eight slots occupy together.
    var slotsWidth: CGFloat {
        CGFloat(HUDLayout.slotCount) * slotSize.width
            + CGFloat(HUDLayout.slotCount - 1) * slotSpacing
    }

    /// Width reserved for the deck — always its deepest footprint, so the bar
    /// does not reflow as the stock drains.
    var deckWidth: CGFloat {
        slotSize.width + CGFloat(HUDLayout.maxDeals - 1) * deckOffsetStep
    }

    /// Total width the two card zones need; must stay within the flexible share.
    var cardZonesWidth: CGFloat { slotsWidth + deckWidth }
}
