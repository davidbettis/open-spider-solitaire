import SwiftUI

/// Win screen (placeholder). Implemented per `docs/specs/animations.md`
/// (cascade) and `docs/specs/high-scores.md` (summary: final score, time,
/// records beaten).
struct WinView: View {
    var body: some View {
        Text("You Win — TODO")
            .navigationTitle("Win")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WinView()
    }
}
