import Foundation
import Observation

/// The hint cycle's state machine (spec §4.2): steps through every legal next
/// move one at a time and loops. Preview-only — it reads the board and never
/// mutates it, so a hint costs points, moves, and undos nothing. The timer
/// keeps running, which is the whole price of a hint.
@MainActor
@Observable
final class HintController {
    /// How long each candidate is previewed before the cycle advances.
    static let stepDuration: Duration = .milliseconds(1100)

    private(set) var candidates: [HintCandidate] = []
    private(set) var index = 0
    private(set) var isCycling = false

    private let provider: HintProvider
    @ObservationIgnored private var cycleTask: Task<Void, Never>?

    init(provider: HintProvider = HintProvider()) {
        self.provider = provider
    }

    /// The candidate being previewed right now, or `nil` while idle.
    var current: HintCandidate? {
        guard isCycling, candidates.indices.contains(index) else { return nil }
        return candidates[index]
    }

    /// Begin (or restart) the cycle for `board`. A board with no legal move
    /// leaves the controller idle — an inert no-op with no feedback (spec §4.1).
    func start(board: Board) {
        let found = provider.candidates(for: board)
        guard !found.isEmpty else { cancel(); return }
        candidates = found
        index = 0
        isCycling = true
        startTicking()
    }

    /// Advance to the next candidate, wrapping at the end. Exposed so the
    /// state machine is testable without waiting on wall-clock time.
    func advance() {
        guard isCycling, !candidates.isEmpty else { return }
        index = (index + 1) % candidates.count
    }

    /// Cancel on any tap (spec §4.2) — clears the preview immediately.
    func cancel() {
        cycleTask?.cancel()
        cycleTask = nil
        isCycling = false
        candidates = []
        index = 0
    }

    /// Any board mutation (move / deal / undo) makes the candidates stale, so
    /// the cycle exits.
    func invalidate() { cancel() }

    private func startTicking() {
        cycleTask?.cancel()
        cycleTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: HintController.stepDuration)
                guard !Task.isCancelled, let self else { return }
                self.advance()
            }
        }
    }
}
