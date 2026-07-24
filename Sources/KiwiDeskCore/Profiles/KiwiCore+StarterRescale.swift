import Foundation

/// Keeping the beginner ladder scaled to the hardware (#485).
///
/// A fresh install seeds the `Starter` ladder sized to its
/// displays (#466), but the seeded profile only covers that one
/// display count — so a later monitor change matched no stored
/// set, fell to the composed *workflow* Standard, and dropped the
/// beginner onto fewer spaces (e.g. Dual Developer's 8, not the
/// ladder's 10) with no digit shortcut past the seeded count.
///
/// These helpers close both halves while the user stays on the
/// ladder baseline: the unmatched-monitor fallback recomposes the
/// *ladder* at the live display count, and the ⌃⌥N digit
/// shortcuts top up additively for the spaces that appear.
extension KiwiCore {
    /// Whether the layout currently on screen is the beginner
    /// `Starter` ladder — either the adopted seed profile (flagged
    /// via `Profile.isStarterLadder`, so the identity survives a
    /// renamed file or an edited mode) or a transient ladder
    /// Standard already recomposed by an earlier display change
    /// (`currentStandard`, sticky across further changes). Only
    /// then does an unmatched monitor change recompose the ladder
    /// rather than a workflow Standard. A saved-as-new copy is the
    /// user's own profile (unflagged) and resolves normally.
    var isOnStarterBaseline: Bool {
        if profiles.currentStandard == StarterLadder.name {
            return true
        }
        guard let name = profiles.currentName,
            let profile = try? profiles.read(name: name)
        else { return false }
        return profile.isStarterLadder
    }

    /// The fallback layout for a monitor change no stored set
    /// covers (#53): the beginner ladder scaled to the live
    /// display count while on the Starter baseline (#485),
    /// otherwise the count's built-in workflow Standard. Nil only
    /// when no display is connected.
    func composeMonitorChangeFallback(
        displays: [Display]
    ) -> ProfileComposition.Composed? {
        let mainID = PositionalDisplays.liveMainID
        guard isOnStarterBaseline else {
            return ProfileComposition.compose(
                displays: displays,
                mainID: mainID
            )
        }
        return ProfileComposition.compose(
            layout: StarterLadder.standardLayout(
                displayCount: displays.count
            ),
            displays: displays,
            mainID: mainID
        )
    }

    /// Adds ⌃⌥N digit shortcuts for spaces that appeared after the
    /// first-run seed authored them — the display-change twin of
    /// `seedDefaultShortcuts` (#485). Strictly additive and
    /// GUI-managed only: a Lua user owns their bindings, and a
    /// digit already bound (a seeded default OR a custom chord) is
    /// never rewritten (see `DefaultKeybindings.digitTopUp`), so it
    /// respects the ten-cap accepted limitation and can't clobber a
    /// user shortcut. Writes the sidecar directly and re-registers
    /// the base bindings in place — NOT `saveGuiConfig`, which
    /// would reload the whole config mid-change (mirrors
    /// `syncGuiSpacesToLive`). A no-op when nothing grew, so it is
    /// safe to call after any GUI-managed apply.
    func topUpDigitShortcuts() {
        guard isGuiManaged, var config = guiConfigStore.load(),
            let index = config.modes.firstIndex(
                where: { $0.isDefault }
            )
        else { return }
        let spaces = SpaceID.deduplicated(
            state.workspaces.allSpaces.map(\.id)
        )
        let added = DefaultKeybindings.digitTopUp(
            existing: config.modes[index].bindings,
            spaces: spaces
        )
        guard !added.isEmpty else { return }
        config.modes[index].bindings.append(
            contentsOf: added
        )
        try? guiConfigStore.save(config)
        // Re-register the base bindings from the just-written
        // sidecar without a full reload, resolving through any
        // active profile override just as `applyStructuredConfig`
        // does (a transient Standard baseline has none).
        guard let lua = keys.lua else { return }
        applyStructuredKeybindings(
            modes: config.modes,
            profile: activeProfileOverrides()?.modes,
            lua: lua
        )
    }
}
