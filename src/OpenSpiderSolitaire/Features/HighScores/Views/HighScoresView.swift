import SwiftUI

/// Per-mode top-10 leaderboard with the mode's time-to-beat and stats
/// (spec §9). Rows show the score and the time from that same game.
struct HighScoresView: View {
    /// A row just earned, to open on and call out in red. `nil` when the screen
    /// is reached from the title screen, which has no row to point at.
    let highlight: HighScoreHighlight?

    @Environment(HighScoresStore.self) private var store
    @Environment(\.chrome) private var chrome

    @State private var mode: SuitMode
    @State private var confirmingReset = false

    init(highlight: HighScoreHighlight? = nil) {
        self.highlight = highlight
        // The highlighted row is on its own mode's board, so that is the one
        // worth landing on; without one, the easiest mode leads as before.
        _mode = State(initialValue: highlight?.mode ?? .one)
    }

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
        // A ten-row table does not all fit in a compact landscape window, so a
        // called-out row is scrolled to rather than left below the fold.
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(leaderboard.entries.enumerated()), id: \.offset) { rank, entry in
                        row(rank: rank + 1, entry: entry)
                            .id(rank + 1)
                        if rank + 1 < leaderboard.entries.count {
                            Divider()
                        }
                    }
                }
                .background(Palette.bar, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .onAppear {
                guard let rank = highlightedRank else { return }
                proxy.scrollTo(rank, anchor: .center)
            }
        }
    }

    /// Rank of the called-out row on the mode currently shown, if it is here at
    /// all — switching the picker to another mode leaves nothing to point at.
    private var highlightedRank: Int? {
        guard let highlight, highlight.mode == mode else { return nil }
        return leaderboard.entries.firstIndex(of: highlight.entry).map { $0 + 1 }
    }

    private func row(rank: Int, entry: ScoreEntry) -> some View {
        let isHighlighted = rank == highlightedRank
        return HStack {
            Text("\(rank)")
                .font(.subheadline.monospacedDigit().weight(rank == 1 ? .bold : .regular))
                .foregroundStyle(rank == 1 ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .frame(width: 28, alignment: .leading)
            // The score the player just earned is called out in red, so they
            // can find their own result in the table at a glance.
            Text("\(entry.score)")
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(isHighlighted ? Color.red : Color.primary)
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
