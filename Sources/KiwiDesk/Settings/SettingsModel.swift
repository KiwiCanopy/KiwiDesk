import AppKit
import Combine
import KiwiDeskCore
import SwiftUI

/// The dashboard's view model: the editable `GuiConfig` plus the
/// live backend state the tabs display (active profile, dirty
/// flag, monitors). Tabs mutate `config` and the change is held
/// until one of the footer's profile actions (Update / Save as
/// new) writes it through `KiwiCore` (#36).
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
    /// True when init.lua has harmless custom Lua (code that
    /// doesn't touch managed vocabulary). Shows the
    /// informational coexistence banner in the visual editor.
    /// Always false when `forcedLuaEditor` is true.
    @Published var hasCustomLua = false
    /// User toggle to edit init.lua directly.
    @Published var showLuaEditor = false
    /// Unsaved GUI edits are pending.
    @Published var isDirty = false

    /// Active saved profile, or nil for a transient state.
    @Published var activeProfile: String?
    /// The built-in Standard currently resolving (no saved
    /// profile covers the live screen count), if any (#53).
    @Published var activeStandard: String?
    /// The live state diverged from the saved profile (e.g.
    /// after a monitor change) — the update prompt.
    @Published var profileDirty = false
    /// A *stored* profile being edited via the banner dropdown,
    /// or nil for the live/active config (#18). Editing a stored
    /// profile seeds the tabs from its JSON and never switches
    /// the running layout.
    @Published var editingProfile: String?
    /// Whether the Canvas (monitor placement) is editable for the
    /// current target: always true live; for a stored profile
    /// only when its monitor set is the one connected now (else
    /// there is no live geometry to render — #18).
    @Published var placementEditable = true
    @Published var profiles: [String] = []
    /// Rich rows for the saved-profiles list (#36): monitor
    /// sets, screen count, default flag, live match.
    @Published var profileSummaries: [ProfileSummary] = []
    /// Screen counts where several profiles claim the default
    /// flag (hand-edited files) — warning badge.
    @Published var duplicateDefaultCounts: [Int] = []
    /// A dismissible warning from the last profile action
    /// (overlapping monitor sets, save failures).
    @Published var profileWarning: String?

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
    /// The sidecar as last loaded — the baseline that decides
    /// whether a save must also regenerate the global files
    /// (see `SettingsModel+Profiles`).
    var savedSidecar: GuiConfig?

    init(core: KiwiCore) {
        self.core = core
        self.config = GuiConfig()
        reload()
    }

    var configURL: URL { core.configURL }
    var displays: [Display] { core.state.workspaces.allDisplays }

    /// Whether the raw Lua editor is currently shown.
    var editingLua: Bool { forcedLuaEditor || showLuaEditor }

    /// Whether the dashboard is editing a stored profile rather
    /// than the live config (#18) — hides the global-only tabs
    /// (Shortcuts, App Rules) and swaps the footer's save action.
    var editingStoredProfile: Bool { editingProfile != nil }

    // MARK: - Sync with the backend

    /// Pulls the current configuration and profile state from
    /// the core into the view model (discards unsaved edits).
    func reload() {
        if let name = editingProfile {
            reloadEditingProfile(name)
            return
        }
        suppressDirty = true
        // Only meaningful while editing a stored profile; reset it
        // so a stale `false` never lingers into live editing.
        placementEditable = true
        var loaded = core.loadGuiConfig()
        // Recovered rows arrive as `.custom`; sort the ones that
        // match a catalog action into their sections before the
        // tabs render them (#4).
        KeybindingImportClassifier.classify(&loaded)
        config = loaded
        suppressDirty = false
        luaSource =
            (try? String(
                contentsOf: configURL,
                encoding: .utf8
            )) ?? ""
        let flags = ManagedConfig.classify(luaSource)
        forcedLuaEditor = flags.foreign
        hasCustomLua = !flags.foreign && flags.custom
        // Baseline for `globalsChanged`: the *overlaid* model,
        // not the raw sidecar — live profile state merged in
        // (e.g. composed monocle-fill spaces in the spaces
        // union) must not read as a global edit, or a
        // tiling-only save would regenerate gui.json and
        // init.lua and leak transient spaces into them.
        // Accepted edges: a genuine global edit still saves
        // the overlaid spaces union, and deleting + re-adding
        // a transient space alone doesn't read as an edit.
        savedSidecar = core.isGuiManaged ? config : nil
        refreshProfiles()
        isDirty = false
    }

    /// Reload path for the profile-dropdown edit mode (#18): seed
    /// the tabs from a stored profile's JSON instead of live
    /// state. A profile that has vanished falls back to live
    /// editing. Stored-profile edits never touch the raw Lua
    /// editor or the global sidecar — only the profile JSON is
    /// written — so `savedSidecar` is cleared.
    private func reloadEditingProfile(_ name: String) {
        guard var loaded = try? core.loadGuiConfig(editing: name)
        else {
            editingProfile = nil
            reload()
            return
        }
        suppressDirty = true
        KeybindingImportClassifier.classify(&loaded)
        config = loaded
        suppressDirty = false
        // Stored-profile editing is mutually exclusive with the
        // raw Lua editor — leaving it on would let a global
        // init.lua write escape edit mode.
        forcedLuaEditor = false
        hasCustomLua = false
        showLuaEditor = false
        savedSidecar = nil
        let live = displays.map(\.fingerprint)
        placementEditable =
            (try? core.profiles.read(name: name))?
            .set(matching: live) != nil
        refreshProfiles()
        isDirty = false
    }

    func refreshProfiles() {
        profiles = core.profiles.list()
        activeProfile = core.profiles.currentName
        activeStandard = core.profiles.currentStandard
        profileDirty = core.profiles.isDirty
        duplicateDefaultCounts =
            core.profiles.duplicateDefaultCounts()
        let live = displays.map(\.fingerprint)
        profileSummaries = core.profiles.allProfiles().map {
            profile in
            ProfileSummary(
                name: profile.name,
                count: profile.monitorCount,
                sets: profile.monitorSets.map(\.monitors),
                isDefault: profile.isDefault,
                matchesLive: profile.set(matching: live) != nil
            )
        }
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

    /// Writes the raw Lua editor's buffer to disk and reloads.
    func saveLuaSource() {
        do {
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
}
