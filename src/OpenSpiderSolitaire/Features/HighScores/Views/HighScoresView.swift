import SwiftUI

/// Per-mode top-10 leaderboard with the mode's time-to-beat and stats
/// (spec §9). Rows show the score and the time from that same game.
struct HighScoresView: View {
    @Environment(HighScoresStore.self) private var store
    @Environment(\.chrome) private var chrome

    @State private var mode: SuitMode = .one
    @State private var confirmingReset = false

    private var leaderboard: Leaderboard { store.leaderboard(mode) }
    private var stats: ModeStats { store.stats(mode) }

    var body: some View {
        ZStack {
            feltBackground
            VStack(spacing: 16) {
                Picker("Mode", selection: $mode) {
                    ForEach(SuitMode.allCases, id: \.self) { Text($0.shortName).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                summaryRow

                if leaderboard.entries.isEmpty {
                    emptyState
                } else {
                    table
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            // A ten-row table stretched over an iPad's width leaves the rank
            // and the time at opposite edges with a field of nothing between.
            .frame(maxWidth: chrome.pick(phone: .infinity, pad: 700))
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("High Scores")
        .navigationBarTitleDisplayMode(.inline)
        // Reset lives here rather than on the title screen: it is the screen
        // showing the data it clears (spec §8 still gates it on a confirmation).
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset", role: .destructive) { confirmingReset = true }
                    .disabled(store.data.leaderboards.isEmpty && store.data.stats.isEmpty)
            }
        }
        .confirmationDialog("Reset all high scores?", isPresented: $confirmingReset,
                            titleVisibility: .visible) {
            Button("Reset Scores", role: .destructive) { store.resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every mode's leaderboard and stats are cleared. This cannot be undone.")
        }
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var summaryRow: some View {
        HStack(spacing: 0) {
            stat("Time to Beat", store.timeToBeat(mode).map(\.clockString) ?? "—")
            stat("Won", "\(stats.gamesWon)")
            stat("Played", "\(stats.gamesStarted)")
            stat("Win Rate", stats.gamesStarted == 0
                 ? "—"
                 : stats.winRate.formatted(.percent.precision(.fractionLength(0))))
        }
        .padding(.vertical, 10)
        .background(Palette.bar, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }

    private var table: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(leaderboard.entries.enumerated()), id: \.offset) { rank, entry in
                    row(rank: rank + 1, entry: entry)
                    if rank + 1 < leaderboard.entries.count {
                        Divider()
                    }
                }
            }
            .background(Palette.bar, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private func row(rank: Int, entry: ScoreEntry) -> some View {
        HStack {
            Text("\(rank)")
                .font(.subheadline.monospacedDigit().weight(rank == 1 ? .bold : .regular))
                .foregroundStyle(rank == 1 ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .frame(width: 28, alignment: .leading)
            Text("\(entry.score)")
                .font(.title3.monospacedDigit().weight(.semibold))
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(entry.time.clockString)
                    .font(.subheadline.monospacedDigit())
                Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy").font(.system(size: 40))
            Text("No wins yet in \(mode.shortName)")
                .font(.headline)
            Text("Finish a game to claim the top spot.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private var feltBackground: some View {
        Palette.table.ignoresSafeArea()
    }
}

#Preview {
    NavigationStack { HighScoresView() }
        .environment(HighScoresStore())
}
