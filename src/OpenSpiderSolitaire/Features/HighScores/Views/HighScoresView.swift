import SwiftUI

/// Per-mode top-10 leaderboard with the mode's time-to-beat and stats
/// (spec §9). Rows show the score and the time from that same game.
struct HighScoresView: View {
    @Environment(HighScoresStore.self) private var store

    @State private var mode: SuitMode = .one

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
        }
        .navigationTitle("High Scores")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        // The bar renders light by default, which clashes with the felt.
        .toolbarColorScheme(.dark, for: .navigationBar)
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
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.7))
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private var table: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(leaderboard.entries.enumerated()), id: \.offset) { rank, entry in
                    row(rank: rank + 1, entry: entry)
                    if rank + 1 < leaderboard.entries.count {
                        Divider().overlay(.white.opacity(0.15))
                    }
                }
            }
            .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private func row(rank: Int, entry: ScoreEntry) -> some View {
        HStack {
            Text("\(rank)")
                .font(.subheadline.monospacedDigit().weight(rank == 1 ? .bold : .regular))
                .foregroundStyle(.white.opacity(rank == 1 ? 1 : 0.6))
                .frame(width: 28, alignment: .leading)
            Text("\(entry.score)")
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(entry.time.clockString)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white)
                Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
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
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white.opacity(0.85))
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private var feltBackground: some View {
        LinearGradient(colors: [Color(red: 0.06, green: 0.36, blue: 0.18),
                                Color(red: 0.03, green: 0.20, blue: 0.10)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

#Preview {
    NavigationStack { HighScoresView() }
        .environment(HighScoresStore(storage: UserDefaultsHighScoresStorage()))
}
