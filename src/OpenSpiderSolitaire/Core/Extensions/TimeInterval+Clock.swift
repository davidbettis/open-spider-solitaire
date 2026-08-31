import Foundation

extension TimeInterval {
    /// `MM:SS` (or `H:MM:SS` past an hour) for the game timer.
    var clockString: String {
        let total = Int(self)
        let seconds = total % 60
        let minutes = (total / 60) % 60
        let hours = total / 3600
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}
