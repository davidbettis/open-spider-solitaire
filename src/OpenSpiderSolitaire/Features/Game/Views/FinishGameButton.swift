import SwiftUI

/// The auto-complete affordance (spec §5.1): appears only while the engine
/// says the board can be finished mechanically, and finishing costs no points.
/// Floats over the tableau so nothing reflows when it appears or leaves.
struct FinishGameButton: View {
    let action: () -> Void

    @Environment(\.chrome) private var chrome

    var body: some View {
        Button(action: action) {
            Label("Finish Game", systemImage: "wand.and.stars")
                .font(chrome.pick(phone: .headline, pad: .title2))
                .padding(.horizontal, 22 * chrome.scale)
                .padding(.vertical, 12 * chrome.scale)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        .accessibilityHint("Finishes the game automatically at no point cost")
    }
}
