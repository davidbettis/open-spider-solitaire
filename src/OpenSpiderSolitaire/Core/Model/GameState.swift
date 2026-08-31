import Foundation

/// The full serializable game snapshot: the board plus lifetime counters, the
/// undo stack, timing, and a schema version for migration. This is what the
/// persistence layer stores for resume-in-progress.
///
/// Score is *derived* from the counters and the board, never stored — see
/// ``Scoring``.
struct GameState: Codable, Sendable {
    /// Bump when the persisted shape changes; migration is handled by the
    /// persistence layer, not the engine.
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var mode: SuitMode
    var board: Board

    /// Monotonic count of committed forward moves (never decremented by undo).
    var moveCount: Int
    /// Monotonic count of undo actions.
    var undoCount: Int

    /// Accumulated play time. Ticks only while `timerStarted` and not paused.
    var elapsed: TimeInterval
    /// Flips true on the first forward move.
    var timerStarted: Bool

    /// Pre-action board snapshots, one per committed forward action. Undo pops
    /// the last to restore the previous board (see ``GameSession``).
    var undoStack: [Board]

    init(
        mode: SuitMode,
        board: Board,
        moveCount: Int = 0,
        undoCount: Int = 0,
        elapsed: TimeInterval = 0,
        timerStarted: Bool = false,
        undoStack: [Board] = [],
        schemaVersion: Int = GameState.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.board = board
        self.moveCount = moveCount
        self.undoCount = undoCount
        self.elapsed = elapsed
        self.timerStarted = timerStarted
        self.undoStack = undoStack
    }
}
