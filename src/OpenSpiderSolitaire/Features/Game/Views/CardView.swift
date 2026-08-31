import SwiftUI

/// Renders a single card, turning it over when the engine reveals it (spec §5).
///
/// **Placeholder art** — the face and back live in ``CardArt``, which is the
/// seam for the vetted CC0 SVG deck (PRD open item).
///
/// The flip angle is derived straight from `card.isFaceUp` rather than held in
/// view state, so the surrounding transaction decides whether it animates —
/// which is what keeps undo instant (spec §7).
struct CardView: View {
    let card: Card
    let size: CGSize

    var body: some View {
        FlippingCard(angle: card.isFaceUp ? 0 : 180, card: card, size: size)
            .frame(width: size.width, height: size.height)
            .animation(Motion.flip, value: card.isFaceUp)
    }
}
