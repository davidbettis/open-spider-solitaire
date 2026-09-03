import Testing
import CoreGraphics
import SwiftUI
@testable import OpenSpiderSolitaire

/// `HUDLayout` is pure sizing math, so the "does the HUD fit?" question is
/// answerable without rendering (mirrors `BoardLayoutTests`).
@Suite("HUDLayout")
struct HUDLayoutTests {
    /// Narrowest supported iPhone through to a large landscape width.
    static let widths: [CGFloat] = [320, 375, 390, 393, 430, 667, 852, 932]
    static let contentHeight = HUDLayout.phoneContentHeight

    @Test("Set slots and deck fit the width left over by the centred stats",
          arguments: widths)
    func cardZonesFit(width: CGFloat) {
        let layout = HUDLayout(containerWidth: width)
        let flexible = max(HUDLayout.phoneMinimumZoneWidth, width - HUDLayout.phoneReservedWidth)
        #expect(layout.cardZonesWidth <= flexible)
    }

    @Test("Slots keep the deck's aspect ratio", arguments: widths)
    func slotAspectRatio(width: CGFloat) {
        let layout = HUDLayout(containerWidth: width)
        #expect(abs(layout.slotSize.height / layout.slotSize.width - BoardLayout.aspectRatio) < 0.0001)
    }

    @Test("Slots never outgrow the bar's content height", arguments: widths)
    func cappedByHeight(width: CGFloat) {
        let layout = HUDLayout(containerWidth: width)
        #expect(layout.slotSize.height <= Self.contentHeight + 0.0001)
    }

    @Test("Wider containers never yield smaller slots")
    func monotonicInWidth() {
        let sizes = Self.widths.map {
            HUDLayout(containerWidth: $0).slotSize.width
        }
        #expect(zip(sizes, sizes.dropFirst()).allSatisfy { $0 <= $1 + 0.0001 })
    }

    @Test("The fan is far narrower than eight side-by-side slots", arguments: widths)
    func overlapBuysWidth(width: CGFloat) {
        let layout = HUDLayout(containerWidth: width)
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
        let layout = HUDLayout(containerWidth: 393)
        #expect(layout.slotSize.width > 23)
        #expect(layout.slotStep == layout.slotSize.width * HUDLayout.slotOverlapStep)
    }

    /// The visible strip of a layered slot has to hold the suit pip (0.4 of a
    /// card width) with margin on both sides, or the pips look cramped.
    @Test("Layered slots leave padding around the suit pip", arguments: widths)
    func pipHasBreathingRoom(width: CGFloat) {
        let layout = HUDLayout(containerWidth: width)
        let visibleStrip = layout.slotStep
        let pip = layout.slotSize.width * 0.4
        #expect(visibleStrip > pip)
        #expect((visibleStrip - pip) / 2 >= layout.slotSize.width * 0.1)
    }

    @Test("Degenerate widths still produce a usable, positive layout")
    func degenerateWidth() {
        let layout = HUDLayout(containerWidth: 0, scale: 0)
        #expect(layout.slotSize.width >= 1)
        #expect(layout.slotSize.height >= 1)
        #expect(layout.deckWidth == layout.slotSize.width)   // the deck is one fixed card
    }

    // MARK: iPad

    /// Portrait and landscape widths for the iPad mini, the 11-inch, and the
    /// 13-inch, plus the narrowest Split View pane that is still regular in
    /// both axes. Anything narrower than that is a **compact** pane, gets
    /// ``Chrome/phone`` from `Chrome.init`, and is covered by `widths` above —
    /// it is not a case this scale is ever asked for. (It would not survive
    /// one either: the iPad's larger stats reserve 317pt of a 507pt pane, so
    /// the slots come out *smaller* than the phone's. That is the layout
    /// answering correctly for type it was never going to be asked to draw.)
    static let padWidths: [CGFloat] = [639, 678, 744, 834, 1032, 1133, 1210, 1366]
    static let padScale = Chrome.pad.scale

    @Test("The bar still fits at the iPad's scale", arguments: padWidths)
    func cardZonesFitOnPad(width: CGFloat) {
        let layout = HUDLayout(containerWidth: width, scale: Self.padScale)
        let flexible = max(HUDLayout.phoneMinimumZoneWidth * Self.padScale,
                           width - HUDLayout.phoneReservedWidth * Self.padScale)
        #expect(layout.cardZonesWidth <= flexible)
        #expect(layout.slotSize.height <= layout.contentHeight + 0.0001)
    }

    @Test("Scaling up grows the bar and its zones together", arguments: padWidths)
    func padZonesAreLargerThanPhoneZones(width: CGFloat) {
        let phone = HUDLayout(containerWidth: width)
        let pad = HUDLayout(containerWidth: width, scale: Self.padScale)
        #expect(pad.contentHeight > phone.contentHeight)
        // Width-limited layouts are the interesting case: the extra height
        // budget must not be handed out to slots the width cannot hold.
        #expect(pad.slotSize.width >= phone.slotSize.width)
    }

    @Test("The bar's height follows the same scale as the zones inside it")
    func barHeightTracksTheScale() {
        let phone = HUDLayout.barHeight(scale: 1)
        let pad = HUDLayout.barHeight(scale: Self.padScale)
        #expect(abs(pad / phone - Self.padScale) < 0.0001)
        #expect(phone == HUDLayout.phoneContentHeight * BoardLayout.aspectRatio)
    }

    /// The pip still has to clear its strip at the larger scale.
    @Test("Layered slots leave padding around the suit pip on iPad",
          arguments: padWidths)
    func padPipHasBreathingRoom(width: CGFloat) {
        let layout = HUDLayout(containerWidth: width, scale: Self.padScale)
        let pip = layout.slotSize.width * 0.4
        #expect(layout.slotStep > pip)
        #expect((layout.slotStep - pip) / 2 >= layout.slotSize.width * 0.1)
    }
}

/// The one decision that separates the two designs.
@Suite("Chrome")
struct ChromeTests {
    @Test("Only a container that is regular in both axes gets the iPad chrome")
    func onlyRegularByRegularIsAPad() {
        #expect(Chrome(horizontal: .regular, vertical: .regular) == .pad)
        // An iPhone Pro Max in landscape: wider than an iPad mini in portrait,
        // and the reason raw width cannot be the signal.
        #expect(Chrome(horizontal: .regular, vertical: .compact) == .phone)
        #expect(Chrome(horizontal: .compact, vertical: .regular) == .phone)
        #expect(Chrome(horizontal: .compact, vertical: .compact) == .phone)
        #expect(Chrome(horizontal: nil, vertical: nil) == .phone)
    }

    @Test("The phone is the baseline the metrics are expressed in")
    func phoneScaleIsIdentity() {
        #expect(Chrome.phone.scale == 1)
        #expect(Chrome.pad.scale > 1)
        #expect(Chrome.phone.pick(phone: "a", pad: "b") == "a")
        #expect(Chrome.pad.pick(phone: "a", pad: "b") == "b")
    }
}
