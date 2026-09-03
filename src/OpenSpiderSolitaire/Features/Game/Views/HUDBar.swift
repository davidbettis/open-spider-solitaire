import SwiftUI

/// Top HUD, in three zones (spec §7): the eight completed-set slots on the
/// left, the live score and MM:SS timer centred, and the deck — which is also
/// the deal control — on the right.
///
/// Sizes come from ``HUDLayout`` and ``Chrome``: the iPhone design, multiplied
/// on iPad so the bar reads as a peer of the tableau rather than a strip of
/// thumbnails above it.
struct HUDBar: View {
    let session: GameSession
    /// Cards waiting at the deck — the next stock deal, or the whole opening
    /// layout while it is still being dealt in.
    let nextDeal: [Card]
    let cardNamespace: Namespace.ID
    let onExit: () -> Void
    let onDeal: () -> Void

    @Environment(\.chrome) private var chrome

    var body: some View {
        GeometryReader { proxy in
            let layout = HUDLayout(containerWidth: proxy.size.width, scale: chrome.scale)
            // Sequential, not stacked: eight slots plus the deck cannot clear a
            // mathematically centred pair of stats on a phone, so the stats are
            // centred *between* the zones instead — and can never overlap them.
            HStack(spacing: 0) {
                menuButton
                SetSlots(completed: session.state.board.completedRuns, layout: layout)
                Spacer(minLength: 12 * chrome.scale)
                centreStats
                Spacer(minLength: 12 * chrome.scale)
                DeckIndicator(dealsRemaining: session.state.board.dealsRemaining,
                              nextDeal: nextDeal,
                              layout: layout,
                              cardNamespace: cardNamespace,
                              onDeal: onDeal)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: HUDLayout.barHeight(scale: chrome.scale))
        .font(chrome.pick(phone: .subheadline, pad: .title3))
        .foregroundStyle(.primary)
        .padding(.horizontal, 16 * chrome.scale)
        .padding(.vertical, 8 * chrome.scale)
        .background(Palette.bar)
    }

    private var menuButton: some View {
        Button(action: onExit) {
            Image(systemName: "chevron.left")
                .font(chrome.pick(phone: .headline, pad: .largeTitle))
        }
        .accessibilityLabel("Menu")
        .padding(.trailing, 8 * chrome.scale)
    }

    private var centreStats: some View {
        HStack(spacing: 16 * chrome.scale) {
            stat("Score", "\(session.displayScore)")
            // Re-renders each second so the timer ticks; source of truth is
            // session.elapsed (frozen while paused / after a win).
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                stat("Time", session.elapsed.clockString)
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(chrome.pick(phone: .caption2, pad: .subheadline))
                .foregroundStyle(.secondary)
            Text(value)
                .font(chrome.pick(phone: Font.headline, pad: Font.title2).monospacedDigit())
        }
        .fixedSize()
    }
}
