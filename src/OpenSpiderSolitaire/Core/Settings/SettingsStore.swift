import Foundation
import Observation

/// Owns the preferences the UI binds to, writing through on every change.
///
/// Settings are changed by hand, a few times at most, so every mutation
/// persists immediately rather than being debounced.
@MainActor
@Observable
final class SettingsStore {
    private(set) var settings: AppSettings

    @ObservationIgnored private let storage: any SettingsStorage

    init(storage: any SettingsStorage = PersistedSettingsStorage(persistence: PersistenceService())) {
        self.storage = storage
        self.settings = storage.load() ?? AppSettings()
    }

    var suitMode: SuitMode {
        get { settings.suitMode }
        set { settings.suitMode = newValue; persist() }
    }

    var appearance: Appearance {
        get { settings.appearance }
        set { settings.appearance = newValue; persist() }
    }

    private func persist() { storage.save(settings) }
}
