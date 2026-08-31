import SwiftUI

/// Main menu with suit-mode selection. Starting a game hands the chosen mode
/// back to `RootView`, which creates the session. (High Scores wiring is the
/// high-scores spec.)
struct MenuView: View {
    let onStart: (SuitMode) -> Void

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
                            Text(title(for: mode))
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
            }
            .padding()
        }
    }

    private func title(for mode: SuitMode) -> String {
        switch mode {
        case .one: return "1 Suit  ·  Easy"
        case .two: return "2 Suits  ·  Medium"
        case .four: return "4 Suits  ·  Hard"
        }
    }
}

#Preview {
    MenuView(onStart: { _ in })
}
