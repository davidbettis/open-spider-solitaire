import Testing
import CoreGraphics
@testable import OpenSpiderSolitaire

/// `HUDLayout` is pure sizing math, so the "does the HUD fit?" question is
/// answerable without rendering (mirrors `BoardLayoutTests`).
@Suite("HUDLayout")
struct HUDLayoutTests {
    /// Narrowest supported iPhone through to a large landscape width.
    static let widths: [CGFloat] = [320, 375, 390, 393, 430, 667, 852, 932]
    static let contentHeight: CGFloat = 30

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

    @Test("Degenerate widths still produce a usable, positive layout")
    func degenerateWidth() {
        let layout = HUDLayout(containerWidth: 0, contentHeight: 0)
        #expect(layout.slotSize.width >= 1)
        #expect(layout.slotSize.height >= 1)
        #expect(layout.deckWidth > layout.slotSize.width)   // depth offsets present
    }
}
