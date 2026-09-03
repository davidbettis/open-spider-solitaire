import SwiftUI

/// Win summary: final score, final time, and which records fell
/// (high-scores §7/§9).
///
/// The dimming scrim is *not* here — `GameBoardView` draws it beneath the win
/// cascade, so the cascading cards read bright rather than through a veil.
struct WinOverlay: View {
    let session: GameSession
    /// `nil` only for the instant between the win and it being recorded.
    let summary: WinSummary?
    let onExit: () -> Void

    @Environment(\.chrome) private var chrome

    var body: some View {
        ZStack {
            VStack(spacing: 16 * chrome.scale) {
                // Already the top of the ladder, so it is the one label that
                // does not step up on iPad — as a system alert's title doesn't.
                Text("You Win!").font(.largeTitle.bold())
                Text("Score \(session.displayScore)  ·  \(session.elapsed.clockString)")
                    .font(chrome.pick(phone: Font.headline, pad: Font.title2).monospacedDigit())
                    .foregroundStyle(.secondary)

                if let summary { records(summary) }

                HStack(spacing: 12 * chrome.scale) {
                    Button("New Game") {
                        Motion.instantly {
                            var rng = SystemRandomNumberGenerator()
                            session.newGame(mode: session.state.mode, rng: &rng)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Menu", action: onExit)
                        .buttonStyle(.bordered)
                }
                .font(chrome.pick(phone: .body, pad: .title3))
                .controlSize(chrome.pick(phone: .regular, pad: .large))
                .padding(.top, 4)
            }
            .padding(32 * chrome.scale)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20 * chrome.scale))
            .padding(40)
        }
    }

    @ViewBuilder
    private func records(_ summary: WinSummary) -> some View {
        let placement = summary.placement
        VStack(spacing: 6) {
            if placement.isNewBest {
                badge("New best in \(session.state.mode.shortName)", systemImage: "crown.fill")
            } else if let rank = placement.rank {
                badge("#\(rank) in \(session.state.mode.shortName)", systemImage: "trophy.fill")
            } else {
                Text("Not a top-\(Leaderboard.maxEntries) finish this time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if placement.beatPreviousBestScore {
                note("Beat your best score")
            }
            if placement.beatPreviousBestTime {
                note("Beat your best time")
            }
            if let toBeat = summary.newTimeToBeat {
                Text("Time to beat: \(toBeat.clockString)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
    }

    private func badge(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.headline)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(.yellow.opacity(0.9)))
            .foregroundStyle(.black)
    }

    private func note(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.seal.fill")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}
