import SwiftUI

/// Title screen: the logo over the app name, then the three places to go.
///
/// Difficulty is not chosen here. It lives in Settings and persists, so Start
/// Game is one tap and the choice is not re-made every launch.
///
/// Uses system surfaces and the system tint throughout, so it follows the
/// platform and the user's appearance setting.
struct MenuView: View {
    let onStart: () -> Void
    let onSettings: () -> Void
    let onHighScores: () -> Void

    var body: some View {
        ZStack {
            Palette.screen.ignoresSafeArea()

            VStack(spacing: 30) {
                header
                actions
            }
            .padding()
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

            // The product name in full. Only the home-screen label is
            // shortened, and that is set in project.yml, not here.
            Text("Open Spider Solitaire")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }

    /// Start Game is prominent; the other two are peers below it.
    private var actions: some View {
        VStack(spacing: 12) {
            Button(action: onStart) {
                Text("Start Game").fontWeight(.semibold).frame(maxWidth: 320).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)

            Button(action: onSettings) {
                Text("Settings").frame(maxWidth: 320).padding(.vertical, 6)
            }
            .buttonStyle(.bordered)

            Button(action: onHighScores) {
                Text("High Scores").frame(maxWidth: 320).padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .buttonBorderShape(.capsule)
    }
}

#Preview {
    NavigationStack {
        MenuView(onStart: {}, onSettings: {}, onHighScores: {})
    }
}
