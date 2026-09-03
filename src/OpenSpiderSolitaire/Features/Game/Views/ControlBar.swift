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

    @Environment(\.chrome) private var chrome

    var body: some View {
        HStack {
            // The destructive role lives on the dialog's confirm button, so
            // this one stays in the bar's white tint.
            Button("New Game") { confirmingNewGame = true }
            Spacer()
            Button("Restart") { confirmingRestart = true }
            Spacer()
            // Undo jumps back; it never plays a move in reverse (spec §7).
            Button("Undo") { Motion.instantly { session.undo() } }
                .disabled(!session.canUndo)
            Spacer()
            Button("Hint", action: onHint)
        }
        .font(chrome.pick(phone: Font.subheadline, pad: Font.title3).weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 24 * chrome.scale)
        .padding(.vertical, 10 * chrome.scale)
        // Four buttons spread over an iPad's full width land nowhere near each
        // other; capped, they stay a group of controls. The bar's background
        // still runs edge to edge.
        .frame(maxWidth: chrome.pick(phone: .infinity, pad: 760))
        .frame(maxWidth: .infinity)
        .background(Palette.bar)
    }
}
