import SwiftUI

/// Top HUD, in three zones (spec §7): the eight completed-set slots on the
/// left, the live score and MM:SS timer centred, and the deck — which is also
/// the deal control — on the right.
struct HUDBar: View {
    let session: GameSession
    let onExit: () -> Void
    let onDeal: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let layout = HUDLayout(containerWidth: proxy.size.width,
                                   contentHeight: HUDLayout.contentHeight)
            // Sequential, not stacked: eight slots plus the deck cannot clear a
            // mathematically centred pair of stats on a phone, so the stats are
            // centred *between* the zones instead — and can never overlap them.
            HStack(spacing: 0) {
                menuButton
                SetSlots(completed: session.state.board.completedRuns, layout: layout)
                Spacer(minLength: 12)
                centreStats
                Spacer(minLength: 12)
                DeckIndicator(dealsRemaining: session.state.board.dealsRemaining,
                              layout: layout,
                              onDeal: onDeal)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: HUDLayout.contentHeight * BoardLayout.aspectRatio)
        .font(.subheadline)
        .foregroundStyle(.white)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.black.opacity(0.25))
    }

    private var menuButton: some View {
        Button(action: onExit) {
            Image(systemName: "chevron.left").font(.headline)
        }
        .tint(.white)
        .accessibilityLabel("Menu")
        .padding(.trailing, 8)
    }

    private var centreStats: some View {
        HStack(spacing: 16) {
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
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.7))
            Text(value).font(.headline.monospacedDigit())
        }
        .fixedSize()
    }
}
