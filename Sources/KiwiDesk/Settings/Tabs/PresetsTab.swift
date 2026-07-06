import KiwiDeskCore
import SwiftUI

/// Tab 1 — Presets & Profiles: applying visual presets and managing
/// saved profiles (05_GUI_Concept §2, Tab 1).
struct PresetsTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                presetSection
                profileSection
            }
            .padding(16)
        }
    }

    private var presetSection: some View {
        SettingsSection("Presets") {
            Text(
                "Applying a preset rewrites the visual tuning. "
                    + "Your keybindings and app rules are kept. "
                    + "Nothing is written until you press Save."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            ForEach(ConfigPreset.allCases) { preset in
                HStack {
                    VStack(alignment: .leading) {
                        Text(preset.title).font(.headline)
                        Text(preset.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Apply") {
                        model.applyPreset(preset)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var profileSection: some View {
        SettingsSection("Saved profiles") {
            if model.profiles.isEmpty {
                Text("No profiles saved yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.profiles, id: \.self) { name in
                HStack {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(.secondary)
                    Text(name)
                    if name == model.activeProfile {
                        Text("active")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.tint.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Button("Load") {
                        model.loadProfile(named: name)
                    }
                }
            }
        }
    }
}
