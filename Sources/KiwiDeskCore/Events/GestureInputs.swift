import Foundation

/// The gesture bindings' inputs and their one resolution (#3199):
/// the base a config load or a verb wrote, the live profile's
/// override and the shortcut base the seeds sit on (#3444),
/// written through `adopt` alone, which `KiwiCore.applyGestures`
/// calls.
@MainActor
public final class GestureInputs {
    public private(set) var base = GestureMap()
    public private(set) var profileOverride: GestureMap?
    public private(set) var shortcutBase = ShortcutBase.standard
    /// The seeds, the base and the override, refusals dropped.
    public private(set) var resolved = GestureSeeds.resolved(
        base: GestureMap(),
        profile: nil,
        shortcutBase: ShortcutBase.standard
    )

    public init() {}

    func adopt(
        base: GestureMap,
        profileOverride: GestureMap?,
        shortcutBase: ShortcutBase
    ) {
        self.base = base
        self.profileOverride = profileOverride
        self.shortcutBase = shortcutBase
        resolved = GestureSeeds.resolved(
            base: base,
            profile: profileOverride,
            shortcutBase: shortcutBase
        )
    }

    /// A config load's reset: the load applies at its tail. The
    /// resolution follows, so nothing reads the last load's.
    func resetInputs() {
        adopt(
            base: GestureMap(),
            profileOverride: nil,
            shortcutBase: ShortcutBase.standard
        )
    }
}
