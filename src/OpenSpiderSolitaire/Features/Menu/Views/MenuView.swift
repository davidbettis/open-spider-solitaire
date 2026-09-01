import SwiftUI

/// Title screen: the logo over the app name, a difficulty picker, and Start
/// Game, with Settings and High Scores on a bottom toolbar.
///
/// Uses system surfaces and the system tint throughout, so it follows the
/// platform and the user's appearance setting.
struct MenuView: View {
    let onStart: (SuitMode) -> Void
    let onHighScores: () -> Void
    let onSettings: () -> Void

    /// Difficulty is now chosen first and started second, so the mode has to
    /// live somewhere between the two taps.
    @State private var mode: SuitMode = .one

    var body: some View {
        ZStack {
            Palette.screen.ignoresSafeArea()

            VStack(spacing: 30) {
                header
                difficulty
                startButton
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                // Plain titles: a bottom bar collapses a Label to its icon
                // whatever label style is asked for, and these want naming.
                Button("Settings", action: onSettings)
                Spacer()
                Button("High Scores", action: onHighScores)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 190)
                // The name sits right below, so the artwork would only repeat it.
                .accessibilityHidden(true)

            Text("Open Spider Solitaire")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }

    private var difficulty: some View {
        VStack(spacing: 10) {
            Text("Choose difficulty")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Difficulty", selection: $mode) {
                ForEach(SuitMode.allCases, id: \.self) { mode in
                    Text(mode.shortName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            // The segments only have room for the suit count, so the
            // difficulty word follows the selection here instead.
            Text(mode.difficultyName)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .animation(nil, value: mode)
        }
    }

    private var startButton: some View {
        Button { onStart(mode) } label: {
            Text("Start Game")
                .fontWeight(.semibold)
                .frame(maxWidth: 320)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

#Preview {
    NavigationStack {
        MenuView(onStart: { _ in }, onHighScores: {}, onSettings: {})
    }
}
