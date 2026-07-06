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

    /// Number of native macOS user Spaces (Mission Control
    /// desktops) currently detected — 0 without SkyLight. Drives
    /// the profile-binding rows (#7).
    @Published var nativeSpaceCount = 0
    /// Mission Control number of the active native Space, for the
    /// "current" badge; nil without SkyLight.
    @Published var currentNativeSpace: Int?

    /// A dismissible in-app warning shown when a keybinding
    /// conflict was just introduced — nil hides the banner. Set
    /// by `noteRecordedCombo` (recording a conflicting shortcut)
    /// and by `adoptIntoGui`/`save`'s raw-Lua path (a batch check
    /// of the resulting config); both also clear it once no
    /// conflict remains. The persistent per-row ⚠️ and its
    /// tooltip are unaffected and always reflect live state.
    @Published var keybindingWarning: String?

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
        var loaded = core.loadGuiConfig()
        // Recovered rows arrive as `.custom`; sort the ones that
        // match a catalog action into their sections before the
        // tabs render them (#4).
        KeybindingImportClassifier.classify(&loaded)
        config = loaded
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
        nativeSpaceCount =
            NativeSpaces.allSpaces().filter(\.isUser).count
        currentNativeSpace = NativeSpaces.activeSpaceNumber()
    }

    // MARK: - Import live keybindings (#4)

    /// Merges the shortcuts currently active in `init.lua` into
    /// the edited config: each recovered mode is matched by name
    /// (created if new), every recovered row upserted by combo,
    /// and the result reclassified so known actions land in their
    /// sections. Marks the config dirty so the user reviews the
    /// import before Save writes it.
    func importCurrentShortcuts() {
        var updated = config
        KeybindingMerge.merge(
            recovered: core.recoverKeybindings(),
            into: &updated
        )
        KeybindingImportClassifier.classify(&updated)
        config = updated
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
                // Free-form Lua isn't checked at input time (no
                // recorder was involved), so set or clear the
                // banner here from the reloaded config.
                warnIfAnyConflict()
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
            // Adopt recovers the file's keybindings (see
            // adoptConfigIntoGui / recoverKeybindings), so a
            // conflict can arrive with the seeded config: set or
            // clear the banner from the result, matching the
            // Lua-editor save path.
            warnIfAnyConflict()
        } catch {
            core.onLog("adopt failed: \(error)")
        }
    }

    // MARK: - Keybinding conflicts (in-app warning)

    /// Called after a `KeyRecorderField.onRecord` commits a new
    /// combo. Warns (naming every current conflict) if that row
    /// now conflicts; else clears the banner once the whole
    /// config has no conflict left, so it doesn't linger once
    /// the last one is fixed. An edit that leaves some *other*
    /// row still conflicting only refreshes the banner if it was
    /// already shown — an unrelated valid edit must not newly
    /// pop it open. The persistent per-row indicator remains the
    /// precise, always-live source of truth either way.
    func noteRecordedCombo(
        _ binding: KeyBinding,
        in bindings: [KeyBinding]
    ) {
        let list = KeybindingConflicts.conflicts(
            in: config.modes
        )
        if KeybindingConflicts.text(for: binding, in: bindings)
            != nil
        {
            keybindingWarning = Self.formatConflicts(list)
        } else if list.isEmpty {
            keybindingWarning = nil
        } else if keybindingWarning != nil {
            keybindingWarning = Self.formatConflicts(list)
        }
    }

    /// Sets or clears the banner from a whole-config check —
    /// used by the two batch paths (Adopt, Lua editor save)
    /// where no single recorder input triggered the check.
    private func warnIfAnyConflict() {
        let list = KeybindingConflicts.conflicts(
            in: config.modes
        )
        keybindingWarning =
            list.isEmpty ? nil : Self.formatConflicts(list)
    }

    /// Renders a named, enumerated summary: a single sentence
    /// for one conflict, or a bulleted list for several.
    private static func formatConflicts(
        _ conflicts: [Conflict]
    ) -> String? {
        guard let only = conflicts.first else { return nil }
        guard conflicts.count > 1 else {
            return "Shortcut for \"\(only.name)\" "
                + sentenceTail(only)
        }
        let lines = conflicts.map { "– \(bulletTail($0))" }
        return "Several shortcuts are conflicting:\n"
            + lines.joined(separator: "\n")
    }

    /// The rest of the single-conflict sentence, after the name.
    private static func sentenceTail(_ conflict: Conflict) -> String {
        switch conflict.target {
        case .unrecognized:
            return "isn't a recognized shortcut."
        case .otherBinding(let who):
            return "is conflicting with \"\(who)\"."
        case .systemShortcut(let name):
            return
                "is conflicting with the macOS shortcut "
                + "\"\(name)\"."
        }
    }

    /// One bullet line's text, after the leading "– ".
    private static func bulletTail(_ conflict: Conflict) -> String {
        switch conflict.target {
        case .unrecognized:
            return "\"\(conflict.name)\" isn't a recognized "
                + "shortcut"
        case .otherBinding(let who):
            return "\"\(conflict.name)\" with \"\(who)\""
        case .systemShortcut(let name):
            return "\"\(conflict.name)\" with the macOS "
                + "shortcut \"\(name)\""
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
