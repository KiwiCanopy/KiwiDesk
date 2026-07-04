import KiwiDeskCore
import SwiftUI

/// Tab 1 — General & Presets: the active config file, best-
/// practice presets, saved-profile management, and the door to
/// the raw Lua editor (05_GUI_Concept §2, Tab 1).
struct GeneralTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                configSection
                presetSection
                profileSection
                advancedSection
            }
            .padding(16)
        }
    }

    private var configSection: some View {
        SettingsSection("Configuration file") {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text(model.configURL.path)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Reveal") {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [model.configURL]
                    )
                }
            }
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

    private var advancedSection: some View {
        SettingsSection("Advanced") {
            Button {
                model.showLuaEditor = true
            } label: {
                Label(
                    "Edit init.lua directly",
                    systemImage: "curlybraces"
                )
            }
            Text(
                "Opens the integrated Lua editor for custom "
                    + "scripting beyond the visual controls."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

/// A titled group used across the dashboard tabs.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }
}
