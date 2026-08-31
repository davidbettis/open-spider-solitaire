import SwiftUI

/// High scores (placeholder). Implemented per `docs/specs/high-scores.md`:
/// per-suit-mode top-N leaderboards with coupled score+time and stats.
struct HighScoresView: View {
    var body: some View {
        Text("High Scores — TODO")
            .navigationTitle("High Scores")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HighScoresView()
    }
}
