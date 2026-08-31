import Foundation

/// A forward player action. Used both to drive gameplay and to express the
/// deal generator's emitted solution (see ``DealGenerator``).
///
/// Auto-clears and auto-flips are *not* moves — they are side effects the
/// engine applies after every move (see ``Rules/applyClearsAndFlips(_:)``).
enum Move: Codable, Sendable, Hashable {
    /// Relocate the top `count` cards of column `from` onto column `to`.
    /// The top `count` cards must form a movable run and be placeable on `to`.
    case relocate(from: Int, count: Int, to: Int)

    /// Deal one card face-up to the top of every column (a full row of 10).
    /// Illegal while any column is empty.
    case deal
}
