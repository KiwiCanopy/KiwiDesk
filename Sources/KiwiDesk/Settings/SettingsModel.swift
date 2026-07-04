import AppKit
import Combine
import KiwiDeskCore
import SwiftUI

/// The dashboard's view model: the editable `GuiConfig` plus the
/// live backend state the tabs display (active profile, dirty
/// flag, monitors). Tabs mutate `config` and the change is held
/// until "Save" writes it through `KiwiCore` (05_GUI_Concept §1).
@MainActor
final class SettingsModel: ObservableObject {
    /// The visually edited configuration.
    @Published var config: GuiConfig {
        didSet {
            if !suppressDirty { isDirty = true }
        }
    }
    /// Raw init.lua shown when the file holds code the visual
    /// editor can't represent, or when the user opts in.
    @Published var luaSource = ""
    /// True while foreign Lua forces the raw editor.
    @Published var forcedLuaEditor = false
    /// User toggle to edit init.lua directly.
    @Published var showLuaEditor = false
    /// Unsaved GUI edits are pending.
    @Published var isDirty = false

    /// Active saved profile, or nil for a transient state.
    @Published var activeProfile: String?
    /// The live state diverged from the saved profile (e.g.
    /// after a monitor change) — the "Save Profile" prompt.
    @Published var profileDirty = false
    @Published var profiles: [String] = []

    let core: KiwiCore
    private var suppressDirty = false

    init(core: KiwiCore) {
        self.core = core
        self.config = GuiConfig()
        reload()
    }

    var configURL: URL { core.configURL }
    var displays: [Display] { core.state.workspaces.allDisplays }

    /// Whether the raw Lua editor is currently shown.
    var editingLua: Bool { forcedLuaEditor || showLuaEditor }

    // MARK: - Sync with the backend

    /// Pulls the current configuration and profile state from
    /// the core into the view model (discards unsaved edits).
    func reload() {
        suppressDirty = true
        config = core.loadGuiConfig()
        suppressDirty = false
        forcedLuaEditor = core.configHasForeignCode
        luaSource =
            (try? String(
                contentsOf: configURL,
                encoding: .utf8
            )) ?? ""
        refreshProfiles()
        isDirty = false
    }

    func refreshProfiles() {
        profiles = core.profiles.list()
        activeProfile = core.profiles.currentName
        profileDirty = core.profiles.isDirty
    }

    // MARK: - Persistence

    /// Writes the current state to disk and applies it live.
    func save() {
        do {
            if editingLua {
                try luaSource.write(
                    to: configURL,
                    atomically: true,
                    encoding: .utf8
                )
                core.loadConfig()
                reload()
            } else {
                try core.saveGuiConfig(config)
                isDirty = false
                forcedLuaEditor = core.configHasForeignCode
                luaSource =
                    (try? String(
                        contentsOf: configURL,
                        encoding: .utf8
                    )) ?? ""
            }
        } catch {
            core.onLog("settings save failed: \(error)")
        }
    }

    func revert() { reload() }

    /// Migrates a hand-written config into GUI management (the
    /// old file is kept as a commented backup) and switches to
    /// the visual editor. See `KiwiCore.adoptConfigIntoGui`.
    func adoptIntoGui() {
        do {
            try core.adoptConfigIntoGui()
            showLuaEditor = false
            reload()
        } catch {
            core.onLog("adopt failed: \(error)")
        }
    }

    // MARK: - Profiles (Tab 1 / sync banner)

    func saveProfile(named name: String) {
        let trimmed = name.trimmingCharacters(
            in: .whitespaces
        )
        guard !trimmed.isEmpty else { return }
        _ = core.execute(
            "save_profile",
            args: [.string(trimmed)]
        )
        refreshProfiles()
    }

    func loadProfile(named name: String) {
        _ = core.execute(
            "load_profile",
            args: [.string(name)]
        )
        reload()
    }

    // MARK: - Presets (Tab 1)

    func applyPreset(_ preset: ConfigPreset) {
        suppressDirty = true
        config = preset.config(basedOn: config)
        suppressDirty = false
        isDirty = true
    }
}
