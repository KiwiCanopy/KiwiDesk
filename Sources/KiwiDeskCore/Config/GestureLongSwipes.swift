import Foundation

extension GestureFamily {
    /// Whether a scroll bound to this family runs the pan, the one
    /// runner whose step follows the travel, so long swipes reach
    /// it (`KiwiCore+GestureRunner`); every other family steps once.
    public var runsThePan: Bool { self == .focus || self == .walk }
}

extension GestureSeeds {
    /// Whether long swipes reach any binding once `base` lies over
    /// the seeds and `profile` over that (#3369): a two-finger swipe
    /// whose whole family, or one axis's, runs the pan. The input
    /// half mirrors `ScrollStepMeter.feed`, whose wheel notch steps
    /// once; a change there owes this predicate the same change.
    public static func longSwipesApply(
        base: GestureMap,
        profile: GestureMap?
    ) -> Bool {
        resolved(base: base, profile: profile).contains { key, action in
            guard key.input == .swipe2 else { return false }
            switch action {
            case .family(let family):
                return family.runsThePan
            case .split(let split):
                return split.axes.values.contains(where: \.runsThePan)
            case .run, .grab:
                return false
            }
        }
    }
}
