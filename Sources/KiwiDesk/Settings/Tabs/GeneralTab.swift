import KiwiDeskCore
import SwiftUI

/// Tab 1 — General & Presets: the active config file, best-
/// practice presets, saved-profile management, and the door to
/// the raw Lua editor (05_GUI_Concept §2, Tab 1).
struct GeneralTab: View {
    @ObservedObject var model: SettingsModel
    /// Advanced is collapsed by default — only interested users
    /// need the config-file path and the raw Lua editor.
    @State private var advancedExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                presetSection
                profileSection
                advancedSection
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

    private var advancedSection: some View {
        DisclosureGroup(isExpanded: $advancedExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration file")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                        NSWorkspace.shared
                            .activateFileViewerSelecting(
                                [model.configURL]
                            )
                    }
                }
                Divider()
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
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Advanced").font(.headline)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
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
