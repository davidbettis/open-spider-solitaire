import SwiftUI

extension Appearance {
    /// Label for the Settings picker.
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// What to hand `preferredColorScheme`. `nil` means "do not override",
    /// which is how SwiftUI expresses following the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
