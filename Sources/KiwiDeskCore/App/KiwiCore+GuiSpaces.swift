import Foundation

/// The `gui.json` sidecar's space list and live state, kept in
/// step in both directions.
///
/// Split from `KiwiCore+GuiConfig.swift` at the §2.1 hard
/// ceiling. The pair belongs together: the cold-boot seed reads
/// the sidecar into live, the reconcile mirror writes live back,
/// and each is only safe because the other runs (#77) — a seed
/// without the mirror re-injects a space a profile load dropped.
extension KiwiCore {
    /// Cold-boot story for GUI-only spaces (#77): seeds live from
    /// the sidecar's `spaces` list so a space that lives *only* in
    /// `gui.json` — no active profile, pin, window, or Lua
    /// `set_mode` backs it — is present in live and survives the
    /// next reload (`overlayLiveProfileState` reads live, not the
    /// sidecar). Runs in `loadConfig` before the first
    /// `handleMonitorChange` adopts a profile, which then ensures
    /// its own spaces on top. Only *adds* (never sets modes or
    /// removes), so a Lua-declared space keeps its mode and no
    /// live-only space is dropped. Safe against resurrecting a
    /// profile-pruned space because every authoritative prune
    /// mirrors live back into the sidecar (`syncGuiSpacesToLive`),
    /// so its `spaces` list is never stale.
    func seedGuiSpaces() {
        guard let config = guiConfigStore.load() else { return }
        for space in config.spaces {
            state.workspaces.ensureSpace(space)
        }
        state.workspaces.reorder(matching: config.spaces)
    }

    /// Mirrors the live space set back into `gui.json` after an
    /// authoritative reconcile changed it (a `load_profile` or an
    /// in-effect edit that pruned stale spaces), keeping the
    /// sidecar a faithful copy of live so the cold-boot seed above
    /// never re-injects a space a profile load dropped (#77).
    /// GUI-managed only (no sidecar otherwise); writes the store
    /// directly — NOT `saveGuiConfig`, which would reload the
    /// config mid-command. A no-op when the list already matches.
    func syncGuiSpacesToLive() {
        guard isGuiManaged, var config = guiConfigStore.load()
        else { return }
        let live = SpaceID.deduplicated(
            state.workspaces.allSpaces.map(\.id)
        )
        guard config.spaces != live else { return }
        config.spaces = live
        try? guiConfigStore.save(config)
    }

    /// Whether the GUI owns the configuration — the ownership
    /// discriminator for the three tiling tiers (#36): only a
    /// GUI-managed config lets the composed Standard own
    /// tiling on an unmatched monitor change; hand-written or
    /// hybrid configs (foreign Lua in `init.lua`)
    /// keep their Lua-declared tiling and get placement-only
    /// resolution. Mirrors the editor, which demotes itself to
    /// the raw-Lua fallback on foreign code.
    public var isGuiManaged: Bool {
        guiConfigStore.exists && !configHasForeignCode
    }

    /// Whether `init.lua` holds code that touches the managed
    /// vocabulary — verbs the GUI
    /// itself generates. When true the visual editor cannot
    /// safely co-own the file and falls back to raw Lua mode.
    /// Harmless custom Lua (e.g. `print`, sketchybar hooks)
    /// does NOT set this; use `configHasCustomCode` for the
    /// informational banner.
    public var configHasForeignCode: Bool {
        guard
            let source = try? String(
                contentsOf: configURL,
                encoding: .utf8
            )
        else { return false }
        return ManagedConfig.hasForeignCode(source)
    }

    /// Whether `init.lua` holds any non-blank, non-comment Lua
    /// (including harmless code that
    /// does not touch managed vocabulary). Used to show the
    /// "you also have custom Lua" banner in the visual editor.
    /// Always `false` when `configHasForeignCode` is `true`
    /// (the raw editor is shown instead of the banner).
    public var configHasCustomCode: Bool {
        guard
            let source = try? String(
                contentsOf: configURL,
                encoding: .utf8
            )
        else { return false }
        return ManagedConfig.hasCustomCode(source)
    }
}
