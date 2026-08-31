import SwiftUI

/// Bottom controls: New Game (confirmed), Undo, and Hint (see
/// `hints-and-autocomplete.md`). Dealing lives on the HUD deck, not here.
struct ControlBar: View {
    let session: GameSession
    @Binding var confirmingNewGame: Bool
    let onHint: () -> Void

    var body: some View {
        HStack {
            // The destructive role lives on the dialog's confirm button, so
            // this one stays in the bar's white tint.
            Button("New Game") { confirmingNewGame = true }
            Spacer()
            // The system's disabled dimming all but vanishes on the dark felt,
            // so the unavailable state is drawn explicitly.
            Button("Undo") { session.undo() }
                .foregroundStyle(.white.opacity(session.canUndo ? 1 : 0.35))
                .disabled(!session.canUndo)
            Spacer()
            Button("Hint", action: onHint)
        }
        .font(.title3.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .tint(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.black.opacity(0.25))
    }
}
