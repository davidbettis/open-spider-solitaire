import Foundation

extension SuitMode {
    /// Short label for pickers and table headings, e.g. "2 Suits".
    var shortName: String {
        switch self {
        case .one: return "1 Suit"
        case .two: return "2 Suits"
        case .four: return "4 Suits"
        }
    }

    /// Difficulty word shown alongside the mode.
    var difficultyName: String {
        switch self {
        case .one: return "Easy"
        case .two: return "Medium"
        case .four: return "Hard"
        }
    }

    /// Menu label, e.g. "2 Suits  ·  Medium".
    var menuTitle: String { "\(shortName)  ·  \(difficultyName)" }
}
