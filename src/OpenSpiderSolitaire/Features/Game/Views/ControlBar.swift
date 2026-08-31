import SwiftUI

/// Bottom controls: New Game (confirmed), Undo, Hint (placeholder — see
/// `hints-and-autocomplete.md`), and Deal.
struct ControlBar: View {
    let session: GameSession
    @Binding var confirmingNewGame: Bool

    var body: some View {
        HStack {
            Button(role: .destructive) { confirmingNewGame = true } label: {
                Label("New", systemImage: "plus.circle")
            }
            Spacer()
            Button { session.undo() } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!session.canUndo)
            Spacer()
            Button {} label: {
                Label("Hint", systemImage: "lightbulb")
            }
            .disabled(true)   // deferred to hints-and-autocomplete
            Spacer()
            Button { session.deal() } label: {
                Label("Deal", systemImage: "square.stack.3d.up.fill")
            }
            .disabled(!session.canDeal)
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .tint(.white)
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(.black.opacity(0.25))
    }
}
