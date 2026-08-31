import Testing
import CoreGraphics
@testable import OpenSpiderSolitaire

/// `HUDLayout` is pure sizing math, so the "does the HUD fit?" question is
/// answerable without rendering (mirrors `BoardLayoutTests`).
@Suite("HUDLayout")
struct HUDLayoutTests {
    /// Narrowest supported iPhone through to a large landscape width.
    static let widths: [CGFloat] = [320, 375, 390, 393, 430, 667, 852, 932]
    static let contentHeight = HUDLayout.contentHeight

    @Test("Set slots and deck fit the width left over by the centred stats",
          arguments: widths)
    func cardZonesFit(width: CGFloat) {
        let layout = HUDLayout(containerWidth: width, contentHeight: Self.contentHeight)
        let flexible = max(HUDLayout.minimumZoneWidth, width - HUDLayout.reservedWidth)
        #expect(layout.cardZonesWidth <= flexible)
    }

    @Test("Slots keep the deck's aspect ratio", arguments: widths)
    func slotAspectRatio(width: CGFloat) {
        let layout = HUDLayout(containerWidth: width, contentHeight: Self.contentHeight)
        #expect(abs(layout.slotSize.height / layout.slotSize.width - BoardLayout.aspectRatio) < 0.0001)
    }

    @Test("Slots never outgrow the bar's content height", arguments: widths)
    func cappedByHeight(width: CGFloat) {
        let layout = HUDLayout(containerWidth: width, contentHeight: Self.contentHeight)
        #expect(layout.slotSize.height <= Self.contentHeight + 0.0001)
    }

    @Test("Wider containers never yield smaller slots")
    func monotonicInWidth() {
        let sizes = Self.widths.map {
            HUDLayout(containerWidth: $0, contentHeight: Self.contentHeight).slotSize.width
        }
        #expect(zip(sizes, sizes.dropFirst()).allSatisfy { $0 <= $1 + 0.0001 })
    }

    @Test("The fan is far narrower than eight side-by-side slots", arguments: widths)
    func overlapBuysWidth(width: CGFloat) {
        let layout = HUDLayout(containerWidth: width, contentHeight: Self.contentHeight)
        let sideBySide = CGFloat(HUDLayout.slotCount) * layout.slotSize.width
        // The fan spans one full card plus each later slot's advance.
        let expected = layout.slotSize.width
            * (1 + CGFloat(HUDLayout.slotCount - 1) * HUDLayout.slotOverlapStep)
        #expect(abs(layout.slotsWidth - expected) < 0.0001)
        #expect(layout.slotsWidth < sideBySide)
    }

    @Test("Overlapping slots are wider than the old side-by-side layout was")
    func slotsGrewFromOverlapping() {
        // Same budget as before, but the fan needs ~6.5 card widths where the
        // side-by-side row needed ~10.9, so each slot gets meaningfully bigger.
        let layout = HUDLayout(containerWidth: 393, contentHeight: Self.contentHeight)
        #expect(layout.slotSize.width > 23)
        #expect(layout.slotStep == layout.slotSize.width * HUDLayout.slotOverlapStep)
    }

    /// The visible strip of a layered slot has to hold the suit pip (0.4 of a
    /// card width) with margin on both sides, or the pips look cramped.
    @Test("Layered slots leave padding around the suit pip", arguments: widths)
    func pipHasBreathingRoom(width: CGFloat) {
        let layout = HUDLayout(containerWidth: width, contentHeight: Self.contentHeight)
        let visibleStrip = layout.slotStep
        let pip = layout.slotSize.width * 0.4
        #expect(visibleStrip > pip)
        #expect((visibleStrip - pip) / 2 >= layout.slotSize.width * 0.1)
    }

    @Test("Degenerate widths still produce a usable, positive layout")
    func degenerateWidth() {
        let layout = HUDLayout(containerWidth: 0, contentHeight: 0)
        #expect(layout.slotSize.width >= 1)
        #expect(layout.slotSize.height >= 1)
        #expect(layout.deckWidth == layout.slotSize.width)   // the deck is one fixed card
    }
}
