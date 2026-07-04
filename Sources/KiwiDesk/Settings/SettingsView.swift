import KiwiDeskCore
import SwiftUI

/// The dashboard shell: a profile/state banner, the five
/// configuration tabs (or the raw Lua editor when the file
/// holds foreign code), and a save/revert footer.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(spacing: 0) {
            ProfileSyncBanner(model: model)
            Divider()
            content
            Divider()
            SettingsFooter(model: model)
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    @ViewBuilder private var content: some View {
        if model.editingLua {
            LuaEditorTab(model: model)
        } else {
            TabView {
                GeneralTab(model: model)
                    .tabItem {
                        Label(
                            "Presets",
                            systemImage: "square.grid.2x2"
                        )
                    }
                CanvasTab(model: model)
                    .tabItem {
                        Label(
                            "Canvas",
                            systemImage: "rectangle.on.rectangle"
                        )
                    }
                SpacesTab(model: model)
                    .tabItem {
                        Label(
                            "Spaces",
                            systemImage: "rectangle.split.3x1"
                        )
                    }
                AppRulesTab(model: model)
                    .tabItem {
                        Label(
                            "App Rules",
                            systemImage: "app.badge"
                        )
                    }
                KeybindingsTab(model: model)
                    .tabItem {
                        Label(
                            "Shortcuts",
                            systemImage: "keyboard"
                        )
                    }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
        }
    }
}

/// Top banner: active profile, the transient/dirty warning, and
/// a "Save Profile" action (05_GUI_Concept §1).
struct ProfileSyncBanner: View {
    @ObservedObject var model: SettingsModel
    @State private var profileName = ""

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.3.group")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.activeProfile ?? "Transient layout")
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(
                        model.profileDirty ? .orange : .secondary
                    )
            }
            Spacer()
            if model.profileDirty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(
                        "The live layout diverged from the "
                            + "saved profile."
                    )
            }
            TextField("Profile name", text: $profileName)
                .frame(width: 140)
                .textFieldStyle(.roundedBorder)
            Button("Save Profile") {
                model.saveProfile(named: profileName)
                profileName = ""
            }
            .disabled(profileName.trimmed.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var statusText: String {
        if model.profileDirty {
            return "Unsaved monitor changes — save to keep them."
        }
        return model.activeProfile == nil
            ? "No profile matches this monitor setup."
            : "Profile is up to date."
    }
}

/// Save / revert footer with the unsaved-changes indicator.
struct SettingsFooter: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        HStack {
            if model.isDirty {
                Label(
                    "Unsaved changes",
                    systemImage: "pencil.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
            Spacer()
            Button("Revert") { model.revert() }
                .disabled(!model.isDirty)
            Button("Save") { model.save() }
                .keyboardShortcut("s")
                .disabled(!model.isDirty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
