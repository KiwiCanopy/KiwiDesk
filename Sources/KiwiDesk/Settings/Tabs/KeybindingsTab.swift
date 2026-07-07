import KiwiDeskCore
import SwiftUI

/// Tab 5 — Keybindings: a mode selector with an optional menu
/// bar icon, plus the Space/Window Management, Open Applications,
/// and Custom sections for the active mode (05_GUI_Concept §2,
/// Tab 5).
struct KeybindingsTab: View {
    @ObservedObject var model: SettingsModel
    @State private var selected = KeyMode.defaultName
    @State private var newMode = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KeybindingConflictBanner(model: model)
                overrideBanner
                modeHeader
                modeIconRow
                NavigationSection(
                    model: model,
                    bindings: bindingsBinding,
                    spaces: model.config.spaces
                )
                if model.config.modes.count > 1 {
                    ChangeModesSection(
                        model: model,
                        bindings: bindingsBinding,
                        modeNames: model.config.modes.map(
                            \.name
                        ),
                        current: selected
                    )
                }
                ApplicationsSection(
                    model: model,
                    bindings: bindingsBinding
                )
                CustomSection(
                    model: model,
                    bindings: bindingsBinding
                )
                // Importing init.lua shortcuts targets the
                // BASE config — not available while editing a
                // profile override (#55 phase 7).
                if !model.editingStoredProfile {
                    importSection
                }
            }
            .padding(16)
            .environment(
                \.keybindingOverrideBase,
                model.overrideBaseRows(mode: selected)
            )
        }
        .onAppear(perform: ensureSelection)
    }

    // MARK: - Override mode (#55 phase 7)

    /// Shown while editing a stored profile: the tab renders
    /// the RESOLVED modes; only rows diverging from the base
    /// are saved into the profile's sparse override.
    @ViewBuilder private var overrideBanner: some View {
        if model.editingStoredProfile {
            SettingsSection("Profile shortcuts") {
                if model.editedProfileOverridesKeys {
                    Label(
                        "This profile overrides base "
                            + "keybindings.",
                        systemImage: "keyboard.badge.ellipsis"
                    )
                    .font(.callout)
                }
                Text(
                    "Dimmed rows are inherited from the base "
                        + "shortcuts and stay in sync with "
                        + "them. Edit a row to override it "
                        + "for this profile only; matching "
                        + "the base again makes it inherited "
                        + "again. Removing an inherited row "
                        + "only resets it — to disable a "
                        + "combo in this profile, rebind it "
                        + "to a no-op action instead."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Import current shortcuts (#4)

    private var importSection: some View {
        SettingsSection("Import current shortcuts") {
            HStack {
                Button("Import current shortcuts") {
                    model.importCurrentShortcuts()
                    ensureSelection()
                }
                Spacer()
            }
            Text(
                "Reads the shortcuts active in init.lua and adds "
                    + "them here, matching each combo. Known "
                    + "actions are sorted into the sections above; "
                    + "anything else lands in Custom Bindings. "
                    + "Review, then Save."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Mode header

    private var modeHeader: some View {
        SettingsSection("Mode") {
            HStack {
                Picker("Active mode", selection: $selected) {
                    ForEach(model.config.modes) { mode in
                        Text(mode.name).tag(mode.name)
                    }
                }
                .frame(maxWidth: 220)
                Spacer()
                TextField("New mode name", text: $newMode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                Button("Add", action: addMode)
                    .disabled(!canAddMode)
            }
            Text(
                "Only the active mode's shortcuts fire. Switch "
                    + "modes with a Custom binding calling "
                    + "KiwiDesk.switch_mode(\"name\")."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var modeIconRow: some View {
        SettingsSection("Menu bar indicator") {
            if selected == KeyMode.defaultName {
                Text(
                    "The default mode uses the standard "
                        + "KiwiDesk icon. Add a mode above to "
                        + "give it its own menu bar icon."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("Icon")
                    ModeIconPicker(icon: iconBinding)
                    Spacer()
                    if canDeleteSelected {
                        Button(
                            "Delete mode",
                            role: .destructive,
                            action: deleteMode
                        )
                    } else {
                        // O4 soft: a base mode the profile
                        // doesn't mention always survives —
                        // removal is not expressible per
                        // profile (#55 phase 7).
                        Text("Base modes can't be removed here")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(
                    "Shown on the menu bar while this mode is "
                        + "active. Pick an SF Symbol, an emoji, "
                        + "or type a single character."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Bindings into the selected mode

    private var modeIndex: Int {
        model.config.modes.firstIndex { $0.name == selected }
            ?? 0
    }

    private var bindingsBinding: Binding<[KeyBinding]> {
        Binding(
            get: { model.config.modes[modeIndex].bindings },
            set: { model.config.modes[modeIndex].bindings = $0 }
        )
    }

    private var iconBinding: Binding<String> {
        Binding(
            get: { model.config.modes[modeIndex].icon ?? "" },
            set: {
                model.config.modes[modeIndex].icon =
                    $0.isEmpty ? nil : $0
            }
        )
    }

    // MARK: - Mode mutations

    /// Live editing: any non-default mode. Override mode:
    /// only modes the PROFILE added — base modes always pass
    /// through (O4 soft), so deleting one is inexpressible.
    private var canDeleteSelected: Bool {
        guard selected != KeyMode.defaultName else {
            return false
        }
        guard let base = model.profileEditingBaseModes else {
            return true
        }
        return !base.contains { $0.name == selected }
    }

    private var canAddMode: Bool {
        let name = newMode.trimmed
        return !name.isEmpty
            && !model.config.modes.contains { $0.name == name }
    }

    private func addMode() {
        let name = newMode.trimmed
        guard canAddMode else { return }
        model.config.modes.append(KeyMode(name: name))
        selected = name
        newMode = ""
    }

    private func deleteMode() {
        guard selected != KeyMode.defaultName else { return }
        model.config.modes.removeAll { $0.name == selected }
        selected = KeyMode.defaultName
    }

    /// Falls back to the default mode if the remembered
    /// selection no longer exists (e.g. after a reload).
    private func ensureSelection() {
        if !model.config.modes.contains(
            where: { $0.name == selected }
        ) {
            selected = KeyMode.defaultName
        }
    }
}
