import SwiftUI

/// The auto-complete affordance (spec §5.1): appears only while the engine
/// says the board can be finished mechanically, and finishing costs no points.
/// Floats over the tableau so nothing reflows when it appears or leaves.
struct FinishGameButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Finish Game", systemImage: "wand.and.stars")
                .font(.headline)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.black)
        .background(Capsule().fill(.yellow))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        .accessibilityHint("Finishes the game automatically at no point cost")
    }
}
