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
    public static let currentFormat = 6
}
