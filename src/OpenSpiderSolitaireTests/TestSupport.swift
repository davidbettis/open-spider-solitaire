import Foundation
@testable import OpenSpiderSolitaire

/// Deterministic RNG so deal-generation tests are reproducible.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Controllable time source for timing tests.
final class FakeClock: TimeSource, @unchecked Sendable {
    var now: TimeInterval
    init(_ now: TimeInterval = 0) { self.now = now }
}

// MARK: - Builders

func makeCard(_ id: Int, _ rank: Rank, _ suit: Suit, up: Bool = true) -> Card {
    Card(id: id, rank: rank, suit: suit, isFaceUp: up)
}

/// A descending same-suit run from `high` down to `low` (bottom→top), face-up.
func makeRun(_ suit: Suit, from high: Int, to low: Int, startID: Int = 0) -> [Card] {
    var cards: [Card] = []
    var id = startID
    for raw in stride(from: high, through: low, by: -1) {
        cards.append(makeCard(id, Rank(rawValue: raw)!, suit, up: true))
        id += 1
    }
    return cards
}

/// A `GameState` wrapping a hand-built board, timer not yet started.
func makeState(mode: SuitMode = .four, board: Board) -> GameState {
    GameState(mode: mode, board: board)
}

func emptyBoard() -> Board {
    Board(tableau: Array(repeating: [], count: 10), stock: [], completedRuns: [])
}

/// In-memory durable store for high-scores tests (spec §12).
final class InMemoryHighScoresStorage: HighScoresStorage {
    private(set) var stored: HighScoresData?
    private(set) var saveCount = 0

    init(_ initial: HighScoresData? = nil) { stored = initial }

    func load() -> HighScoresData? { stored }
    func save(_ data: HighScoresData) {
        stored = data
        saveCount += 1
    }
}

/// A `ScoreEntry` with a date derived from `day`, so ordering tests are
/// deterministic without depending on the wall clock.
func makeEntry(score: Int, time: TimeInterval, day: Int = 0) -> ScoreEntry {
    ScoreEntry(score: score, time: time, date: Date(timeIntervalSince1970: TimeInterval(day) * 86_400))
}
