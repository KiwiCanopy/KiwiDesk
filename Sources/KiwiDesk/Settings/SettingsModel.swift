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
            if !suppressDirty { recomputeDirty() }
        }
    }
    /// Raw init.lua shown when the file holds code the visual
    /// editor can't represent, or when the user opts in.
    @Published var luaSource = "" {
        didSet {
            if !suppressDirty { recomputeDirty() }
        }
    }
    /// True while foreign Lua forces the raw editor.
    @Published var forcedLuaEditor = false
    /// True when init.lua has harmless custom Lua (code that
    /// doesn't touch managed vocabulary). Shows the
    /// informational coexistence banner in the visual editor.
    /// Always false when `forcedLuaEditor` is true.
    @Published var hasCustomLua = false
    /// User toggle to edit init.lua directly.
    @Published var showLuaEditor = false
    /// Unsaved GUI edits are pending. A live comparison
    /// against the as-loaded baselines, not a latched flag —
    /// manually undoing an edit clears the footer again.
    @Published var isDirty = false
    /// The state as last loaded/saved — what `isDirty`
    /// compares against. Set only by `apply(_:)` (every clean
    /// transition funnels through `reload()`).
    var cleanConfig = GuiConfig()
    var cleanLuaSource = ""

    func recomputeDirty() {
        isDirty =
            config != cleanConfig
            || luaSource != cleanLuaSource
    }

    /// Active saved profile, or nil for a transient state.
    @Published var activeProfile: String?
    /// The built-in Standard currently resolving (no saved
    /// profile covers the live screen count), if any (#53).
    @Published var activeStandard: String?
    /// The live state diverged from the saved profile (e.g.
    /// after a monitor change) — the update prompt.
    @Published var profileDirty = false
    /// The dashboard's edit target (#64/#18): the live config,
    /// or a stored profile edited via the banner dropdown —
    /// seeded from its JSON, never switching the running
    /// layout. Written only by `selectEditTarget` and the
    /// reload fallback; every mode-dependent field derives
    /// from it through the single `reload()`.
    @Published var target: EditTarget = .live
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
    /// A recorder edit was applied to the running hotkeys
    /// without being saved (#123, live target only). When the
    /// staged edits carrying it are discarded (`reload()`),
    /// the running registration must follow them back to the
    /// saved config — no ghost hotkeys. See
    /// `SettingsModel+LiveApply.swift`.
    var liveKeysApplied = false
    /// Guards the `config.didSet` dirty flag during reload
    /// cycles; its only writer is `apply(_:)` in
    /// `SettingsModel+EditTarget.swift`.
    var suppressDirty = false
    /// The sidecar as last loaded — the baseline that decides
    /// whether a save must also regenerate the global files
    /// (see `SettingsModel+Profiles`).
    var savedSidecar: GuiConfig?
    /// The base gui.json modes while editing a stored profile
    /// — the diff baseline for the Shortcuts tab's override
    /// mode (#55 phase 7). nil during live editing. Updated
    /// only inside the reload cycle, which republishes
    /// `config`, so views recompute together.
    var profileEditingBaseModes: [KeyMode]?
    /// The base gui.json app→space rules while editing a
    /// stored profile — the App Rules tab's override-mode
    /// baseline (#109), same lifecycle as
    /// `profileEditingBaseModes`. nil during live editing.
    var profileEditingBaseAppRules: [String: SpaceID]?

    init(core: KiwiCore) {
        self.core = core
        self.config = GuiConfig()
        reload()
    }

    var configURL: URL { core.configURL }
    var displays: [Display] { core.state.workspaces.allDisplays }

    /// Whether the raw Lua editor is currently shown.
    var editingLua: Bool { forcedLuaEditor || showLuaEditor }

    /// The stored profile being edited, or nil while live —
    /// derived from `target` (#64).
    var editingProfile: String? {
        if case .storedProfile(let name) = target {
            return name
        }
        return nil
    }

    /// Whether the dashboard is editing a stored profile rather
    /// than the live config (#18) — hides App Rules, renders
    /// the Shortcuts tab in override mode (#55 phase 7), and
    /// swaps the footer's save action. The editing surface
    /// lives in `SettingsModel+ProfileOverrides.swift`.
    var editingStoredProfile: Bool { target != .live }

    // MARK: - Sync with the backend

    // `reload()` and `selectEditTarget` — the single edit-mode
    // state machine — live in `SettingsModel+EditTarget.swift`
    // (#64).

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
        KeybindingImportClassifier.classify(
            &updated,
            recoverResizeStep: true
        )
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

}
