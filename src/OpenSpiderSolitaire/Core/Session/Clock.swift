import Foundation

/// A monotonic time source, injected so game timing is deterministic in tests.
///
/// Named `TimeSource` (not `Clock`) to avoid colliding with the standard
/// library's `Clock` protocol.
protocol TimeSource: Sendable {
    /// Seconds since an arbitrary fixed reference. Only differences are used.
    var now: TimeInterval { get }
}

/// Production time source backed by the system wall clock.
struct SystemClock: TimeSource {
    var now: TimeInterval { Date().timeIntervalSinceReferenceDate }
}
