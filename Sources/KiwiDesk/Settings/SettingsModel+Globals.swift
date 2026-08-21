import Foundation
import KiwiDeskCore

/// Saving `gui.json` globals, split from
/// `SettingsModel+Profiles.swift` for the file ceiling (#516).
///
/// The one field list lives here, and both consumers go through
/// it: "did a global change?" and "adopt the globals as clean".
extension SettingsModel {
    /// The fields `gui.json` owns, in ONE place. Both consumers
    /// — "did a global change?" and "adopt the globals as
    /// clean" — go through this, so a seventh global cannot be
    /// added to one and forgotten in the other. Two hand-kept
    /// copies would drift silently: a save that never clears
    /// the footer, or a footer that never offers the save.
    static func copyGlobals(
        from source: GuiConfig,
        into target: inout GuiConfig
    ) {
        target.format = source.format
        target.layers = source.layers
        target.appRules = source.appRules
        target.floatRules = source.floatRules
        target.ignoreRules = source.ignoreRules
        target.profileBindings = source.profileBindings
        target.spaces = source.spaces
    }

    var globalsChanged: Bool {
        guard let saved = savedSidecar else { return true }
        var probe = saved
        Self.copyGlobals(from: config, into: &probe)
        return probe != saved
    }

    // MARK: - Saving globals while paused (#516)

    /// Writes `gui.json` and nothing else.
    ///
    /// None of the six global fields has a monitor dependency,
    /// so the #335 gate that blocks profile saves while
    /// Accessibility is off — a profile persisted then would
    /// record a degenerate 0-screen set and never resolve —
    /// should never have reached them. It did, because
    /// `saveGuiConfig` had exactly one caller and that caller
    /// was behind the gate.
    ///
    /// Its own narrow method on purpose: routing through
    /// `persist(named:)` would drag along the overlapping-
    /// monitor-set warning and a "Saving failed" message that
    /// names a profile this save never touched.
    func saveGlobalsWhilePaused() {
        // Self-guarding, and on the CANONICAL predicate. The
        // footer's classifier also checks this, but a write that
        // can seize config ownership must not depend on its only
        // caller remembering to (AGENTS §5: refine the one
        // `isGuiManaged` predicate, never mirror it).
        guard core.isGuiManaged else { return }
        // `spaces` is one of the six, so its freshness net runs
        // here too — without it a space created live while the
        // dashboard sat open is pruned on save.
        //
        // But ONLY when live is trustworthy. The net appends
        // every live space the staged list lacks, so on an
        // Accessibility-off cold boot it appends
        // `StateCoordinator`'s boot default and the user's saved
        // list silently grows a spurious "1" on every save. That
        // state cannot have live-created spaces to rescue —
        // the engine never started — so the net has nothing to
        // do and is skipped. (Caught by a probe after the seed
        // fix: the save wrote ["work", "mail", "1"].)
        if core.state.workspaces.allSpaces.map(\.id)
            != [SpaceID(1)]
        {
            core.mergeLiveSpaces(
                into: &config,
                seededWith: seedSpaces
            )
            // `reload()` normally re-seeds this; this path skips
            // reload by design, so without the hand re-seed a
            // merged-in space can never be deleted again this
            // session — the next merge's `known` set would miss
            // it while live still holds it, and re-append it.
            seedSpaces = config.spaces
        }
        do {
            if core.lua == nil {
                // Cold paused boot: `core.start()` never ran, so
                // `saveGuiConfig`'s reload would be the session's
                // FIRST — it would execute init.lua, register
                // Carbon hotkeys (which need no Accessibility and
                // so would genuinely fire), apply a profile
                // against an empty display set and retile, all
                // while the dashboard says "paused". Write the
                // store directly instead; `core.start()` picks the
                // file up when permission arrives. Two precedents
                // do exactly this for the same reason —
                // `syncGuiSpacesToLive` and `topUpDigitShortcuts`.
                try core.guiConfigStore.save(config)
            } else {
                // Revoked mid-session: the engine is running and
                // keybindings still fire, so the new modes and
                // rules must reach it now.
                try core.saveGuiConfig(config)
            }
        } catch {
            profileWarning = L(
                "settings.globals_save_failed",
                "Saving settings failed: %1$@",
                "\(error)"
            )
            core.onLog("globals save failed: \(error)")
            return
        }
        adoptGlobalsBaseline()
    }

    /// Marks ONLY the global fields clean.
    ///
    /// Deliberately not `reload()`: nothing was written for the
    /// profile/tiling side, so re-seeding from disk would throw
    /// away staged tiling edits this save never persisted. If
    /// tiling is also dirty the footer must keep saying so.
    private func adoptGlobalsBaseline() {
        Self.copyGlobals(from: config, into: &cleanConfig)
        var sidecar = savedSidecar ?? config
        Self.copyGlobals(from: config, into: &sidecar)
        savedSidecar = sidecar
        recomputeDirty()
        // The write may have reloaded the config, and that can
        // load a DIFFERENT profile via the native-Space binding
        // (SkyLight works without Accessibility), so the footer's
        // profile state and drift caption would be stale. Safe
        // here where `reload()` is not: `refreshProfiles` never
        // touches `config`, so the staged tiling edits this
        // partial-clean contract protects are untouched.
        refreshProfiles()
        // The recorder's rollback point was minted against the
        // pre-save modes. Every other save path retires it —
        // `saveLuaSource` nils it outright, `persist` reaches
        // `restoreLiveKeySessionIfNeeded` via reload — and a
        // stale one silently reverts a staged action edit on the
        // next recorder change.
        liveKeySession = nil
    }
}
