import SwiftUI

/// The single source of truth for motion timing (spec §4), so every animated
/// event in the game shares one vocabulary. Values are starting points to tune
/// on device (spec AI-1).
enum Motion {
    /// A card or run travelling to a new home.
    static let glide = Animation.spring(response: 0.30, dampingFraction: 0.82)
    /// One card of a deal; successive cards are staggered by ``dealStagger``.
    static let deal = Animation.easeOut(duration: 0.18)
    /// A face-down card turning over.
    static let flip = Animation.easeInOut(duration: 0.22)
    /// A completed King→Ace run leaving the tableau.
    static let clear = Animation.easeInOut(duration: 0.45)
    /// One card of the win cascade.
    static let cascade = Animation.easeIn(duration: 0.35)
    static let dealStagger: TimeInterval = 0.04

    /// Apply a board mutation with **no** animation — undo's first-class
    /// requirement (spec §7), and how a whole new board should arrive.
    ///
    /// Every path that mutates the board picks animated or instant
    /// deliberately; there is no default.
    static func instantly(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }
}
