import Foundation

/// The gesture bindings' inputs and their one resolution (#3199):
/// the base a config load or a verb wrote and the live profile's
/// override, written through `adopt` alone, which
/// `KiwiCore.applyGestures` calls.
@MainActor
public final class GestureInputs {
    public private(set) var base = GestureMap()
    public private(set) var profileOverride: GestureMap?
    /// The seeds, the base and the override, refusals dropped.
    public private(set) var resolved = GestureSeeds.resolved(
        base: GestureMap(),
        profile: nil
    )

    public init() {}

    func adopt(base: GestureMap, profileOverride: GestureMap?) {
        self.base = base
        self.profileOverride = profileOverride
        resolved = GestureSeeds.resolved(base: base, profile: profileOverride)
    }

    /// A config load's reset: the load applies at its tail.
    func resetInputs() {
        base = GestureMap()
        profileOverride = nil
    }
}
