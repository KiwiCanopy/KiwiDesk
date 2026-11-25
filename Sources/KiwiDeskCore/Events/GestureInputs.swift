import Foundation

/// The gesture bindings' inputs and their one resolution (#3199):
/// the per-layer base a config load or a verb wrote, the live
/// profile's override, the shortcut base the seeds sit on (#3444)
/// and the active keybinding layer, whose map alone resolves
/// (#3535), written through `adopt` alone, which
/// `KiwiCore.applyGestures` calls.
@MainActor
public final class GestureInputs {
    public private(set) var base = LayerGestures()
    public private(set) var profileOverride: LayerGestures?
    public private(set) var shortcutBase = ShortcutBase.standard
    /// The layer `resolved` is the active layer's of.
    public private(set) var layer = KeyLayer.defaultName
    /// The active layer's seeds, base and override, refusals
    /// dropped.
    public private(set) var resolved = GestureSeeds.resolved(
        base: GestureMap(),
        profile: nil,
        shortcutBase: ShortcutBase.standard,
        layer: KeyLayer.defaultName
    )

    public init() {}

    func adopt(
        base: LayerGestures,
        profileOverride: LayerGestures?,
        shortcutBase: ShortcutBase,
        layer: String
    ) {
        self.base = base
        self.profileOverride = profileOverride
        self.shortcutBase = shortcutBase
        self.layer = layer
        resolved = GestureSeeds.resolved(
            base: base[layer],
            profile: profileOverride?.maps[layer],
            shortcutBase: shortcutBase,
            layer: layer
        )
    }

    /// A config load's reset: the load applies at its tail. The
    /// resolution follows, so nothing reads the last load's.
    func resetInputs() {
        adopt(
            base: LayerGestures(),
            profileOverride: nil,
            shortcutBase: ShortcutBase.standard,
            layer: KeyLayer.defaultName
        )
    }
}
