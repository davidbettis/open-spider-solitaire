import SwiftUI

/// Top HUD: menu, live floored score, live MM:SS timer, and deals remaining.
struct HUDBar: View {
    let session: GameSession
    let onExit: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Button(action: onExit) {
                Label("Menu", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            }
            .tint(.white)

            Spacer()
            stat("Sets", "\(session.completedSets)/\(GameSession.totalSets)")
            Spacer()
            stat("Score", "\(session.displayScore)")
            Spacer()
            // Re-renders each second so the timer ticks; source of truth is
            // session.elapsed (frozen while paused / after a win).
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                stat("Time", session.elapsed.clockString)
            }
            Spacer()
            stat("Deals", "\(session.state.board.dealsRemaining)")
        }
        .font(.subheadline)
        .foregroundStyle(.white)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.black.opacity(0.25))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.7))
            Text(value).font(.headline.monospacedDigit())
        }
    }
}
