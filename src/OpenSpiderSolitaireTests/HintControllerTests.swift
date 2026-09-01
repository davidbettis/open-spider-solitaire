import Testing
@testable import OpenSpiderSolitaire

/// The hint cycle's state machine (spec §4.2). `advance()` is driven directly
/// so the tests never wait on wall-clock time.
@MainActor
@Suite("HintController")
struct HintControllerTests {

    /// Q♠ over two red Kings: exactly two candidates.
    private func twoCandidateBoard() -> Board {
        var tableau: [[Card]] = (0..<10).map { [makeCard(900 + $0, .two, .clubs)] }
        tableau[0] = [makeCard(1, .king, .spades), makeCard(2, .queen, .spades)]
        tableau[1] = [makeCard(3, .king, .hearts)]
        tableau[2] = [makeCard(4, .king, .diamonds)]
        return Board(tableau: tableau, stock: [], completedRuns: [])
    }

    /// Ten lone 2♣ and no empty column: nothing is legal.
    private func stuckBoard() -> Board {
        Board(tableau: (0..<10).map { [makeCard(900 + $0, .two, .clubs)] },
              stock: [], completedRuns: [])
    }

    @Test("Starting enters the cycle at the first candidate")
    func startEntersCycle() {
        let controller = HintController()
        controller.start(board: twoCandidateBoard())
        #expect(controller.isCycling)
        #expect(controller.candidates.count == 2)
        #expect(controller.current?.destinationColumn == 1)
    }

    @Test("Advancing steps through the candidates in order")
    func advanceStepsThrough() {
        let controller = HintController()
        controller.start(board: twoCandidateBoard())
        #expect(controller.current?.destinationColumn == 1)
        controller.advance()
        #expect(controller.current?.destinationColumn == 2)
    }

    @Test("The cycle ends after the last candidate rather than looping")
    func cycleEndsAfterTheLastCandidate() {
        let controller = HintController()
        controller.start(board: twoCandidateBoard())
        controller.advance()          // second and final candidate
        #expect(controller.isCycling)

        controller.advance()          // nothing left to show
        #expect(!controller.isCycling)
        #expect(controller.current == nil)
        #expect(controller.candidates.isEmpty)
    }

    @Test("A single-candidate board ends after showing that one move")
    func singleCandidateEnds() {
        var tableau: [[Card]] = (0..<10).map { [makeCard(900 + $0, .two, .clubs)] }
        tableau[0] = [makeCard(1, .queen, .spades)]
        tableau[1] = [makeCard(2, .king, .hearts)]
        let board = Board(tableau: tableau, stock: [], completedRuns: [])

        let controller = HintController()
        controller.start(board: board)
        #expect(controller.candidates.count == 1)
        controller.advance()
        #expect(!controller.isCycling)
    }

    @Test("A tap cancels the cycle and clears the preview")
    func cancelClearsPreview() {
        let controller = HintController()
        controller.start(board: twoCandidateBoard())
        controller.cancel()
        #expect(!controller.isCycling)
        #expect(controller.current == nil)
        #expect(controller.candidates.isEmpty)
    }

    @Test("A board mutation invalidates the cycle")
    func invalidateExitsCycle() {
        let controller = HintController()
        controller.start(board: twoCandidateBoard())
        controller.invalidate()
        #expect(!controller.isCycling)
        #expect(controller.current == nil)
    }

    @Test("With no legal move the control is an inert no-op")
    func stuckBoardStaysIdle() {
        let controller = HintController()
        controller.start(board: stuckBoard())
        #expect(!controller.isCycling)
        #expect(controller.current == nil)
    }

    @Test("Advancing while idle does nothing")
    func advanceWhileIdleIsSafe() {
        let controller = HintController()
        controller.advance()
        #expect(controller.current == nil)
        #expect(controller.index == 0)
    }

    @Test("Hints change no board state, no counters, and no score")
    func hintsAreFree() {
        var rng = SplitMix64(seed: 42)
        let session = GameSession(mode: .four, rng: &rng, clock: FakeClock())
        let board = session.state.board
        let score = session.displayScore
        let moves = session.state.moveCount
        let undos = session.state.undoCount

        let controller = HintController()
        controller.start(board: session.state.board)
        controller.advance()
        controller.advance()
        controller.cancel()

        #expect(session.state.board == board)
        #expect(session.displayScore == score)
        #expect(session.state.moveCount == moves)
        #expect(session.state.undoCount == undos)
        #expect(!session.state.timerStarted)   // a hint never starts the clock
    }
}
