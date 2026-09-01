import Testing
@testable import OpenSpiderSolitaire

@MainActor
struct SettingsStoreTests {

    @Test("A fresh install defaults to 1 suit and the system appearance")
    func defaults() {
        let store = SettingsStore(storage: InMemorySettingsStorage())
        #expect(store.suitMode == .one)
        #expect(store.appearance == .system)
    }

    @Test("Changing difficulty persists immediately")
    func difficultyPersists() {
        let storage = InMemorySettingsStorage()
        let store = SettingsStore(storage: storage)

        store.suitMode = .four
        #expect(storage.stored?.suitMode == .four)
        #expect(storage.saveCount == 1)
    }

    @Test("Changing appearance persists immediately")
    func appearancePersists() {
        let storage = InMemorySettingsStorage()
        let store = SettingsStore(storage: storage)

        store.appearance = .dark
        #expect(storage.stored?.appearance == .dark)
    }

    @Test("Settings survive a relaunch, and the two are independent")
    func survivesRelaunch() {
        let storage = InMemorySettingsStorage()
        let first = SettingsStore(storage: storage)
        first.suitMode = .two
        first.appearance = .light

        let second = SettingsStore(storage: storage)
        #expect(second.suitMode == .two)
        #expect(second.appearance == .light)
    }

    @Test("Setting one preference does not disturb the other")
    func preferencesAreIndependent() {
        let store = SettingsStore(storage: InMemorySettingsStorage())
        store.appearance = .dark
        store.suitMode = .four
        #expect(store.appearance == .dark)
        #expect(store.suitMode == .four)
    }
}
