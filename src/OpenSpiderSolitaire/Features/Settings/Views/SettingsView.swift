import SwiftUI

/// Settings placeholder. Nothing is configurable yet — there is no settings
/// model, and the persistence layer's `DurableData` keeps a slot open for one
/// (`persistence-and-migration.md` §5).
struct SettingsView: View {
    var body: some View {
        ZStack {
            Palette.screen.ignoresSafeArea()
            VStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                Text("No settings yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
