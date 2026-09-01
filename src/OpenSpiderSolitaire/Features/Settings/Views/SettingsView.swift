import SwiftUI

/// Settings: difficulty for the next game, and the app's appearance.
///
/// Both write through immediately (``SettingsStore`` persists on every change),
/// so there is no Save button and nothing to discard.
struct SettingsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                Picker("Difficulty", selection: $store.suitMode) {
                    ForEach(SuitMode.allCases, id: \.self) { mode in
                        Text(mode.menuTitle).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Difficulty")
            } footer: {
                Text("Applies to the next game you start. A game already in progress keeps the difficulty it was dealt with.")
            }

            Section {
                Picker("Appearance", selection: $store.appearance) {
                    ForEach(Appearance.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            } footer: {
                Text("System follows your device's light or dark setting.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(SettingsStore())
}
