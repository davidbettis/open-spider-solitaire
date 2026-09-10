import SwiftUI

/// Title screen: the logo over the app name and what the app is, then the
/// three places to go.
///
/// Difficulty is not chosen here. It lives in Settings and persists, so Start
/// Game is one tap and the choice is not re-made every launch.
///
/// Uses system surfaces and the system tint throughout, so it follows the
/// platform and the user's appearance setting.
struct MenuView: View {
    let onStart: () -> Void
    /// Resume the game waiting behind this screen, or `nil` when there is none.
    /// Optional rather than a flag, so "no game in flight" cannot render a
    /// button that would do nothing.
    let onContinue: (() -> Void)?
    let onSettings: () -> Void
    let onHighScores: () -> Void

    @Environment(\.chrome) private var chrome

    var body: some View {
        ZStack {
            Palette.screen.ignoresSafeArea()

            VStack(spacing: 30 * chrome.scale) {
                header
                actions
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(spacing: 12 * chrome.scale) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: chrome.pick(phone: 190, pad: 320))
                // The name sits right below, so the artwork would only repeat it.
                .accessibilityHidden(true)

            // Tighter than the stack's own spacing: the tagline belongs to the
            // name, and at 12pt it read as a third loose element under it.
            VStack(spacing: 6 * chrome.scale) {
                // The product name in full. Only the home-screen label is
                // shortened, and that is set in project.yml, not here.
                Text("Open Spider Solitaire")
                    .font(chrome.pick(phone: .headline, pad: .title))
                    .foregroundStyle(.primary)

                // The principles from the README, in one line. Italic and
                // secondary so it supports the name rather than competing.
                Text("An open source card game. No ads, in-app purchases, or tracking of any sort.")
                    .font(chrome.pick(phone: .subheadline, pad: .title3))
                    .italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    // Wraps on the same measure as the buttons below, so the
                    // screen has one column edge rather than two.
                    .frame(maxWidth: columnWidth)
            }
        }
    }

    /// Start Game is prominent; the rest are peers below it. Continue sits
    /// directly under Start Game rather than with Settings and High Scores,
    /// because it is a way into a game and those are not.
    private var actions: some View {
        VStack(spacing: 12 * chrome.scale) {
            Button(action: onStart) {
                Text("Start Game").fontWeight(.semibold).frame(maxWidth: columnWidth).padding(.vertical, 6 * chrome.scale)
            }
            .buttonStyle(.borderedProminent)

            if let onContinue {
                Button(action: onContinue) {
                    Text("Continue Game").frame(maxWidth: columnWidth).padding(.vertical, 6 * chrome.scale)
                }
                .buttonStyle(.bordered)
            }

            Button(action: onSettings) {
                Text("Settings").frame(maxWidth: columnWidth).padding(.vertical, 6 * chrome.scale)
            }
            .buttonStyle(.bordered)

            Button(action: onHighScores) {
                Text("High Scores").frame(maxWidth: columnWidth).padding(.vertical, 6 * chrome.scale)
            }
            .buttonStyle(.bordered)
        }
        .font(chrome.pick(phone: .body, pad: .title3))
        .controlSize(.large)
        .buttonBorderShape(.capsule)
    }

    /// The screen's one column measure: the three buttons read as a stack of
    /// peers at a single width, and the tagline wraps to that same edge. Wider
    /// on iPad, where a 320pt column would look marooned.
    private var columnWidth: CGFloat {
        chrome.pick(phone: 320, pad: 420)
    }
}

#Preview("No game in flight") {
    NavigationStack {
        MenuView(onStart: {}, onContinue: nil, onSettings: {}, onHighScores: {})
    }
}

#Preview("Game in flight") {
    NavigationStack {
        MenuView(onStart: {}, onContinue: {}, onSettings: {}, onHighScores: {})
    }
}
