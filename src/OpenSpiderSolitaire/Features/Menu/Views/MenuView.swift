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

            // The product name in full. Only the home-screen label is
            // shortened, and that is set in project.yml, not here.
            Text("Open Spider Solitaire")
                .font(chrome.pick(phone: .headline, pad: .title))
                .foregroundStyle(.primary)
        }
    }

    /// Start Game is prominent; the other two are peers below it.
    private var actions: some View {
        // One width for all three, so they read as a stack of peers; wider on
        // iPad, where a 320pt column would look marooned.
        let width = chrome.pick(phone: 320.0, pad: 420.0)
        return VStack(spacing: 12 * chrome.scale) {
            Button(action: onStart) {
                Text("Start Game").fontWeight(.semibold).frame(maxWidth: width).padding(.vertical, 6 * chrome.scale)
            }
            .buttonStyle(.borderedProminent)

            Button(action: onSettings) {
                Text("Settings").frame(maxWidth: width).padding(.vertical, 6 * chrome.scale)
            }
            .buttonStyle(.bordered)

            Button(action: onHighScores) {
                Text("High Scores").frame(maxWidth: width).padding(.vertical, 6 * chrome.scale)
            }
            .buttonStyle(.bordered)
        }
        .font(chrome.pick(phone: .body, pad: .title3))
        .controlSize(.large)
        .buttonBorderShape(.capsule)
    }
}

#Preview {
    NavigationStack {
        MenuView(onStart: {}, onSettings: {}, onHighScores: {})
    }
}
