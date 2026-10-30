import Foundation

extension GuiConfig {
    /// Format version of the gui.json schema (#902); 0 =
    /// unversioned legacy. **Deliberately NOT bumped by the
    /// scroll-duration rename (#1020)**: `settings` is absent from
    /// `CodingKeys`, so the renamed key never reaches this file —
    /// a bump would rewrite every gui.json for nothing and make
    /// the previous release refuse one this build wrote. That note
    /// is the ruling `SetupBundle.currentFormat` cites, and the
    /// one the `resize.feedback` retirement took again (#1255,
    /// `RefusalSoundMigrationTests`) and the `float_nudge` one
    /// (#1674, `FloatPlacementMigrationTests`) — `settings` is
    /// still absent, so neither key was ever here.
    ///
    /// **2 (#1147)**: `profile_bindings` values became objects,
    /// which IS a `CodingKeys` key of this file, so the step is
    /// dead without the bump.
    ///
    /// **3 (#1436)**: a binding's `profile` became the per-count
    /// list `profiles` — the same key, so the same bump.
    ///
    /// **4 (#1609)**: a `profiles` entry may be an object scoped to
    /// one screen setup. No step — a bare name still means all
    /// setups — so the bump is the refusal an older reader owes.
    ///
    /// **5 (#1797)**: a layer holds one chord per Space verb, so a
    /// top-up's extras are dropped.
    ///
    /// **6 (#1511)**: a stored app shortcut calls `focus_or_spawn`,
    /// so a GUI-written `pull_or_spawn` call is renamed.
    ///
    /// **7 (#2265)**: KiwiHub's sides open through `kiwihub.show`,
    /// so a stored `show_*` panel call is renamed. A number the
    /// release branch holds and main does not — kept above main's
    /// at each sync (profiles.md ▸ A long-lived release branch).
    ///
    /// **8 (#2309)**: the layouts side became View before release,
    /// so a stored `kiwihub.show("layouts")` is renamed. Above
    /// main's, as 7 is.
    ///
    /// **9 (#2324)**: `desktop_spaces` moved to `machine.json`
    /// (`MachineConfig.moves`), so the key is stripped here
    /// once the store has carried it across.
    ///
    /// **10 (#2324)**: `profile_bindings` moved to `bindings.json`,
    /// stripped here once the store has carried it across.
    ///
    /// Not bumped by #2237: `min_window_size` lives in
    /// `TilingSettings`, which `gui.json` does not encode.
    ///
    /// **11 (#2324)**: the top-ups' `shortcut_offer` travels in the
    /// file, so an older build latches read-only rather than drop
    /// the offer on a write. No step: the stamp alone crosses.
    ///
    /// **12 (#2460)**: `desktop_shortcut_base` became
    /// `shortcut_base`, which covers every tier
    /// (`migratingShortcutBase`).
    ///
    /// **13 (owner ruling, 2026-10-21)**: the shared look's motion
    /// paths `animations.on_shelf` / `shelf_duration` became
    /// `on_expand` / `expand_duration`
    /// (`migratingShelfGlideOntoExpand`).
    ///
    /// **14 (#2524)**: `space.cue` became `space.transition`
    /// (`migratingSpaceCueOntoTransition`).
    ///
    /// **15 (#2235)**: `overflow_style` retired from `stack` and
    /// `track` (`migratingRetiredOverflowStyle`).
    ///
    /// **16 (#2493)**: the per-layout `wrap_focus` switches retired
    /// for `focus_wrap` (`migratingRetiredWrapFocus`).
    ///
    /// **17 (#2446)**: the seeded pin row on ⌃⌥P runs Pocket
    /// (`migratingPinChordOntoPocket`).
    ///
    /// **18 (#2797)**: the drag markers' palette paths left the
    /// shared look's colours (`migratingRetiredDragLook`).
    public static let currentFormat = 18
}
