import SwiftUI

/// Bottom controls: New Game and Restart (both confirmed), Undo, and Hint
/// (see `hints-and-autocomplete.md`). Dealing lives on the HUD deck, not here.
///
/// New Game draws a *different* deal; Restart replays the current one.
struct ControlBar: View {
    let session: GameSession
    @Binding var confirmingNewGame: Bool
    @Binding var confirmingRestart: Bool
    let onHint: () -> Void

    var body: some View {
        HStack {
            // The destructive role lives on the dialog's confirm button, so
            // this one stays in the bar's white tint.
            Button("New Game") { confirmingNewGame = true }
            Spacer()
            Button("Restart") { confirmingRestart = true }
            Spacer()
            // The system's disabled dimming all but vanishes on the dark felt,
            // so the unavailable state is drawn explicitly.
            // Undo jumps back; it never plays a move in reverse (spec §7).
            Button("Undo") { Motion.instantly { session.undo() } }
                .foregroundStyle(.white.opacity(session.canUndo ? 1 : 0.35))
                .disabled(!session.canUndo)
            Spacer()
            Button("Hint", action: onHint)
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .tint(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.black.opacity(0.25))
    }
}
