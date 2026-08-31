import CoreGraphics

/// An in-flight drag of a run picked up from the tableau (spec §6.2). Ephemeral
/// UI-only state — no game rules here.
struct DragState {
    let sourceColumn: Int
    /// Index within the source column where the dragged run starts.
    let sourceIndex: Int
    /// The cards being dragged (bottom→top), for the drag overlay.
    let cards: [Card]
    /// Current pointer location in the tableau ("board") coordinate space.
    var location: CGPoint
}
