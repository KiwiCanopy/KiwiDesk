import AppKit
import Foundation

/// The "seed / overlay a `GuiConfig` from live or stored-profile
/// state" helpers behind `loadGuiConfig()` / `loadGuiConfig(
/// editing:)` — split out of `KiwiCore+GuiConfig.swift` to stay
/// under the file-size ceiling.
extension KiwiCore {
    /// Copies a *stored* profile's tiling into the model —
    /// sibling of `overlayLiveProfileState`, reading the profile
    /// instead of live state. Pins come from the set covering the
    /// connected monitors (empty when none matches, i.e. the
    /// Canvas can't be edited for this profile right now).
    func overlayProfileState(
        _ config: inout GuiConfig,
        from profile: Profile
    ) {
        config.settings = profile.settings
        config.spaceModes = profile.spaceModes
        config.mainSpaces = Set(profile.mainSpaces)
        let live = state.workspaces.allDisplays
            .map(\.fingerprint)
        config.spacePins =
            profile.set(matching: live)?.spaceMonitorMap ?? [:]
        // The space set is the profile's own — NOT unioned with
        // the live sidecar's spaces, or editing a profile for
        // other hardware would graft this machine's spaces into
        // it on save (mirrors `applyProfileScopedState`, #18).
        // Stored order is authoritative (#75); `orderedSpaces`
        // appends any declared space absent from the list.
        config.spaces = profile.orderedSpaces
        config.fallbackSpace = profile.fallbackSpace
        // Shortcuts tab in override mode (#55 phase 7): the
        // tabs edit the RESOLVED modes (base + this profile's
        // sparse override); `overwriteProfile` diffs them back
        // against the base on save.
        config.layers = ConfigResolver.resolvedLayers(
            base: config.layers,
            profile: profile.layers
        )
        // App Rules tab in override mode (#109): same
        // resolve-edit-diff cycle over the flat rule map.
        config.appRules = ConfigResolver.resolvedAppRules(
            base: config.appRules,
            profile: profile.appRules
        )
        config.floatRules =
            profile.floatRules?.resolved(
                onto: config.floatRules,
                normalizing: FloatRules.normalizedRule
            ) ?? config.floatRules
        config.ignoreRules =
            profile.ignoreRules?.resolved(
                onto: config.ignoreRules,
                normalizing: IgnoreRules.normalizedRule
            ) ?? config.ignoreRules
    }

    /// Copies the live profile-scoped state into the model:
    /// tiling settings, monitor pins and the Main role from
    /// live, and the per-space MODES from the saved profile.
    ///
    /// The modes are the one field that does NOT come from live
    /// (#1179): the draft narrates the PROFILE, the quick menu
    /// narrates the session. Everything else mirrors live
    /// deliberately — which spaces exist and their ORDER are
    /// live's to state (#75/#55, below), and pins and the Main
    /// role travel with them.
    func overlayLiveProfileState(
        _ config: inout GuiConfig
    ) {
        config.settings = tiler.settings
        var modes: [SpaceID: LayoutMode] = [:]
        var live: [SpaceID] = []
        // SPARSE, so a live space the profile never carried
        // keeps its live mode rather than being read as `.bsp`
        // and then written as one (code review, 2026-08-31).
        let saved = savedProfileModes()
        for space in state.workspaces.allSpaces {
            live.append(space.id)
            let mode = saved?[space.id] ?? space.mode
            if mode != .bsp {
                modes[space.id] = mode
            }
        }
        config.spaceModes = modes
        // Live state is authoritative for which spaces EXIST
        // and for their ORDER (#75/#55): every profile apply
        // and every GUI save reconciles the live order via
        // `WorkspaceManager.reorder`, so the live list already
        // carries the chosen display order — while the
        // sidecar's list can be stale (e.g. right after
        // loading a profile whose order differs). A bare space
        // only in `gui.json` is seeded into live at boot
        // (`seedGuiSpaces`, #77), so it is present here too.
        config.spaces = SpaceID.deduplicated(live)
        config.spacePins = spacePins
        config.mainSpaces = mainSpaces
        config.fallbackSpace = fallbackSpace
    }

    /// Save-time freshness net for the dashboard: appends
    /// spaces that appeared live *after* the model was seeded
    /// (a profile load or a hotkey-created space while the
    /// dashboard sat open). Without it, `applyProfileScopedState`
    /// read those spaces as deleted-in-the-Spaces-tab and pruned
    /// them — snapping focus to the first space on every save.
    /// Staged edits stay authoritative: a space present in
    /// `seed` but removed from the model was deleted by the
    /// user this session and is not resurrected.
    public func mergeLiveSpaces(
        into config: inout GuiConfig,
        seededWith seed: [SpaceID]
    ) {
        var known = Set(seed)
        known.formUnion(config.spaces)
        for space in state.workspaces.allSpaces
        where !known.contains(space.id) {
            config.spaces.append(space.id)
            if space.mode != .bsp {
                config.spaceModes[space.id] = space.mode
            }
        }
    }

    /// The starter space set a fresh install gets — chosen for the
    /// connected screens' shapes (#678 Phase 4 pass 11, turn 15b;
    /// superseding the five-per-display ladder of #466 and the
    /// flat nine of #270). One generator behind both first-run
    /// pads (empty list and the single-space signature) so the
    /// count can't drift between them; the per-space MODES and
    /// pins are applied and persisted separately by
    /// `seedFirstRunStarterProfile()`, since `gui.json` carries
    /// only the space list and shortcuts.
    func starterSpaces() -> [SpaceID] {
        StarterSetup.spaces(sizes: firstRunSizes())
    }

    /// First-run display sizes in positional order — the one
    /// accessor behind both the `gui.json` space list and the
    /// Starter profile, so the two can't size to different
    /// screens.
    func firstRunSizes() -> [CGSize] {
        StarterSetup.sizes(
            displays: firstRunDisplays(),
            mainID: PositionalDisplays.liveMainID
        )
    }

    /// Connected displays for first-run seeding. `loadConfig` runs
    /// before the event loop's first `publishDisplays`, so live
    /// state is still empty on a genuine first launch — fall back
    /// to the same `NSScreen` source `publishDisplays` reads.
    /// Prefers live state when present (tests seed displays there
    /// to drive this deterministically). The one accessor behind
    /// both the `gui.json` space count and the Starter profile, so
    /// the two can't size to different display counts.
    func firstRunDisplays() -> [Display] {
        let live = state.workspaces.allDisplays
        if !live.isEmpty { return live }
        return NSScreen.screens.compactMap { $0.kiwiDisplay }
    }

    /// `firstRunDisplays().count`, floored at one — a Mac always
    /// drives at least one screen even if the read comes back
    /// empty (headless CI).
    func firstRunDisplayCount() -> Int {
        max(1, firstRunDisplays().count)
    }

    /// Builds an editable model from the running configuration.
    /// Keybindings and mode icons are recovered from the source
    /// file via `recoverKeybindings` (#4); the sidecar owns them
    /// once saved.
    func guiConfigSeed() -> GuiConfig {
        var config = GuiConfig()
        config.settings = tiler.settings
        config.appRules = globalAppRuleBase
        config.spacePins = spacePins
        config.mainSpaces = mainSpaces
        config.fallbackSpace = fallbackSpace
        config.layers = recoverKeybindings()
        config.floatRules = globalFloatRuleBase
        config.ignoreRules = globalIgnoreRuleBase
        var modes: [SpaceID: LayoutMode] = [:]
        var defined: [SpaceID] = []
        for space in state.workspaces.allSpaces {
            defined.append(space.id)
            if space.mode != .bsp { modes[space.id] = space.mode }
        }
        config.spaceModes = modes
        // De-dup only — live order is authoritative (#75).
        config.spaces = SpaceID.deduplicated(
            defined + Array(modes.keys)
        )
        if config.spaces.isEmpty {
            config.spaces = starterSpaces()
        }
        config.profileBindings = desktopBindings
        config.desktopSpaces = persistedDesktopSpaces()
        seedDefaultShortcuts(&config)
        return config
    }

    /// First-run starter shortcuts (#91): when no mode carries
    /// a single binding — a fresh install, or an `init.lua`
    /// that declares none — the base `default` mode gets the
    /// starter set so a new user can drive KiwiDesk immediately.
    /// Also pads `config.spaces` on the bare first-run signature
    /// (see below) — a deliberate second effect, kept here rather
    /// than in `guiConfigSeed` because it depends on this same
    /// no-binding guard. Never fires once a user (or Lua) authored
    /// any binding, in any mode — idempotent by that guard, so the
    /// space padding is a first-run-only effect and never pollutes
    /// a Lua-managed user's space list.
    private func seedDefaultShortcuts(
        _ config: inout GuiConfig
    ) {
        guard
            config.layers.allSatisfy({ $0.bindings.isEmpty }),
            let index = config.layers.firstIndex(
                where: { $0.isDefault }
            )
        else { return }
        // First run reports only the ACTIVE Space (#270): the live
        // list is a single numbered space (usually ["1"]), which
        // would seed only ⌃⌥1. Pad just that bare signature to the
        // per-display set the empty state already uses, so the
        // scaled digit shortcuts (⌃⌥1–5 on one display, …+0 on two)
        // all work out of the box (#466). A named or multi-space
        // list is a configured setup — left exactly as discovered
        // so the seed never invents spaces the user didn't (dedup
        // keeps the live space first, #75).
        if config.spaces.count == 1,
            Int(config.spaces[0].raw) != nil
        {
            config.spaces = SpaceID.deduplicated(
                config.spaces + starterSpaces()
            )
        }
        config.layers[index].bindings =
            DefaultKeybindings.bindings(
                spaces: config.spaces,
                resizeStep: Int(config.settings.resizeStep)
            )
    }
}
