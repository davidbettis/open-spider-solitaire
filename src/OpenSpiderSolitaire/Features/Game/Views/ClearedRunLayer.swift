import SwiftUI

/// A King→Ace run that just completed, on its way out (spec §5).
struct ClearingRun: Identifiable, Equatable {
    /// Distinguishes successive clears so the animation restarts for each.
    let id: Int
    let cards: [Card]
    /// The column it cleared from, so it leaves from where it lay.
    let column: Int
}

/// The run-clear celebration: the thirteen cards lift out of their column and
/// sweep up toward the completed-set slots in the HUD, fading as they go.
/// Purely decorative — the engine removed these cards already.
struct ClearedRunLayer: View {
    let run: ClearingRun
    let layout: BoardLayout

    @State private var away = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(run.cards.enumerated()), id: \.element.id) { position, card in
                CardView(card: card, size: layout.cardSize)
                    .offset(x: layout.columnX(run.column) + (away ? drift(position) : 0),
                            y: away ? -layout.cardSize.height * 1.4
                                    : layout.topInset + CGFloat(position) * layout.faceUpPeek)
                    .opacity(away ? 0 : 1)
                    .scaleEffect(away ? 0.45 : 1, anchor: .top)
                    .rotationEffect(.degrees(away ? drift(position) * 0.25 : 0), anchor: .top)
                    .animation(Motion.clear.delay(Double(position) * 0.025), value: away)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .task(id: run.id) {
            away = false
            // Let the resting frame render once, so the sweep starts from the
            // column rather than being coalesced away.
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            away = true
        }
    }

    /// Fan the cards apart a little as they leave, so it reads as a flourish
    /// rather than a single block sliding off.
    private func drift(_ position: Int) -> CGFloat {
        let centred = CGFloat(position) - CGFloat(run.cards.count - 1) / 2
        return centred * layout.cardSize.width * 0.18
    }
}
