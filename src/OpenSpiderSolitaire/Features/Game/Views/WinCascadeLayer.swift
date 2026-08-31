import SwiftUI

/// One card in the win cascade, with the launch parameters that decide its arc.
private struct CascadeCard: Identifiable {
    let id: Int
    let card: Card
    let start: CGPoint
    let horizontalSpeed: Double
    let initialRise: Double
    let launchDelay: Double
}

/// The classic Solitaire win cascade (spec §6): the completed runs pour off
/// their slots and bounce their way down and across the screen.
///
/// Resolves AI-4 in favour of `TimelineView` plus closed-form physics over
/// keyframes: each card's position is a pure function of elapsed time, so
/// nothing has to be stepped, stored, or kept in sync — and the whole layer is
/// decorative, non-interactive, and safe to dismiss at any moment.
struct WinCascadeLayer: View {
    let completedRuns: [CompletedRun]
    let cardSize: CGSize

    private static let gravity: Double = 1500
    private static let bounceDamping: Double = 0.62
    /// Below this speed a card has settled and stops bouncing.
    private static let restingSpeed: Double = 45

    /// When this cascade began. Every position is measured from here — using a
    /// wall-clock value instead would put each card thousands of seconds into
    /// its flight and off-screen before the first frame.
    @State private var start = Date.now

    var body: some View {
        GeometryReader { proxy in
            let cards = launches(in: proxy.size)
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(start)
                Canvas { graphics, size in
                    draw(cards, elapsed: elapsed, in: graphics, size: size)
                } symbols: {
                    ForEach(cards) { item in
                        CardFace(card: item.card, size: cardSize).tag(item.id)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Physics

    /// Where each card starts and how hard it is thrown. Deterministic, so the
    /// cascade looks the same every time rather than jittering per frame.
    private func launches(in size: CGSize) -> [CascadeCard] {
        var result: [CascadeCard] = []
        for (runIndex, run) in completedRuns.enumerated() {
            for (position, id) in run.cardIDs.enumerated() {
                let rank = Rank(rawValue: 13 - position) ?? .king
                // Fan the launch points across the top, near the set slots.
                let x = size.width * (0.08 + 0.11 * Double(runIndex % 8))
                let direction: Double = runIndex.isMultiple(of: 2) ? 1 : -1
                result.append(CascadeCard(
                    id: id,
                    card: Card(id: id, rank: rank, suit: run.suit, isFaceUp: true),
                    start: CGPoint(x: x, y: cardSize.height * 0.6),
                    horizontalSpeed: direction * (70 + 26 * Double(position % 5)),
                    initialRise: -(120 + 40 * Double(position % 4)),
                    launchDelay: Double(runIndex) * 0.45 + Double(position) * 0.075))
            }
        }
        return result
    }

    /// Closed-form position: fall, bounce off the floor with damping, repeat.
    /// `nil` once the card has left the screen or has not launched yet.
    private func position(_ item: CascadeCard, elapsed: Double, in size: CGSize) -> CGPoint? {
        let t = elapsed - item.launchDelay
        guard t >= 0 else { return nil }

        let floor = size.height - cardSize.height / 2
        var y = item.start.y
        var velocity = item.initialRise
        var remaining = t

        // At most a few dozen bounces before the card is at rest.
        for _ in 0..<40 {
            let a = 0.5 * WinCascadeLayer.gravity
            let discriminant = velocity * velocity - 4 * a * (y - floor)
            guard discriminant > 0 else { break }
            let timeToFloor = (-velocity + discriminant.squareRoot()) / (2 * a)

            if timeToFloor > remaining || timeToFloor <= 0 {
                y += velocity * remaining + a * remaining * remaining
                break
            }
            remaining -= timeToFloor
            y = floor
            velocity = -(velocity + WinCascadeLayer.gravity * timeToFloor)
                * WinCascadeLayer.bounceDamping
            if abs(velocity) < WinCascadeLayer.restingSpeed { break }
        }

        let x = item.start.x + item.horizontalSpeed * t
        guard x > -cardSize.width, x < size.width + cardSize.width else { return nil }
        return CGPoint(x: x, y: min(y, floor))
    }

    private func draw(_ cards: [CascadeCard], elapsed: Double,
                      in graphics: GraphicsContext, size: CGSize) {
        for item in cards {
            guard let point = position(item, elapsed: elapsed, in: size),
                  let symbol = graphics.resolveSymbol(id: item.id)
            else { continue }
            graphics.draw(symbol, at: point)
        }
    }
}
