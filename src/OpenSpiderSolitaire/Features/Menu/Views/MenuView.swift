import SwiftUI

/// Main menu: suit-mode selection, High Scores, and Reset Scores (PRD Screens
/// §1). Starting a game hands the chosen mode back to `RootView`, which creates
/// the session.
struct MenuView: View {
    @Environment(HighScoresStore.self) private var highScores

    let onStart: (SuitMode) -> Void
    let onHighScores: () -> Void

    @State private var confirmingReset = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.06, green: 0.36, blue: 0.18),
                                    Color(red: 0.03, green: 0.20, blue: 0.10)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Image(systemName: "suit.spade.fill").font(.system(size: 56))
                    Text("Spider Solitaire").font(.largeTitle.bold())
                }
                .foregroundStyle(.white)

                VStack(spacing: 14) {
                    Text("Choose difficulty")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                    ForEach(SuitMode.allCases, id: \.self) { mode in
                        Button { onStart(mode) } label: {
                            Text(mode.menuTitle)
                                .fontWeight(.semibold)
                                .frame(maxWidth: 280)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.white.opacity(0.9))
                        .foregroundStyle(.black)
                    }
                }

                VStack(spacing: 10) {
                    Button("High Scores", action: onHighScores)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(.white)
                    Button("Reset Scores", role: .destructive) { confirmingReset = true }
                        .buttonStyle(.borderless)
                        .font(.subheadline)
                        .tint(.white.opacity(0.75))
                }
            }
            .padding()
        }
        .confirmationDialog("Reset all high scores?", isPresented: $confirmingReset,
                            titleVisibility: .visible) {
            Button("Reset Scores", role: .destructive) { highScores.resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every mode's leaderboard and stats are cleared. This cannot be undone.")
        }
    }
}

#Preview {
    MenuView(onStart: { _ in }, onHighScores: {})
        .environment(HighScoresStore())
}
