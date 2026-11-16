import Testing

@testable import KiwiDeskCore

/// Whether Long swipes reaches any binding (#3369 ▸ Ruling): only a
/// two-finger swipe whose whole family, or one axis's, runs the pan.
@Suite("Long swipes reach (#3369)")
struct GestureLongSwipesTests {
    private let pan = GestureSeeds.panKeys
    private let step = GestureSeeds.stepKeys

    /// The seeds bind ⌃⌥ two-finger swipe to focus.
    @Test("the seeds reach it")
    func seedsReach() {
        #expect(GestureSeeds.longSwipesApply(base: GestureMap(), profile: nil))
    }

    /// Unbinding the seeded focus swipe leaves the Space step and
    /// the wheel walk, neither of which a long swipe reaches.
    @Test("no pan swipe, no reach")
    func noPanSwipe() {
        var base = GestureMap()
        base[GestureKey(.swipe2, pan)] = .unbound
        #expect(!GestureSeeds.longSwipesApply(base: base, profile: nil))
    }

    /// The walk reaches it, on any keys, whole or on one axis.
    @Test("a walk swipe or a pan axis reaches it")
    func walkAndAxis() {
        var base = GestureMap()
        base[GestureKey(.swipe2, pan)] = .unbound
        base[GestureKey(.swipe2, step)] = .bound(.family(.walk))
        #expect(GestureSeeds.longSwipesApply(base: base, profile: nil))
        base[GestureKey(.swipe2, step)] = .bound(
            .split(GestureSplit(axes: [.upDown: .focus]))
        )
        #expect(GestureSeeds.longSwipesApply(base: base, profile: nil))
        base[GestureKey(.swipe2, step)] = .bound(
            .split(GestureSplit(axes: [.upDown: .space]))
        )
        #expect(!GestureSeeds.longSwipesApply(base: base, profile: nil))
    }

    /// A profile's own map lies over the base.
    @Test("the profile layer decides last")
    func profileDecides() {
        var profile = GestureMap()
        profile[GestureKey(.swipe2, pan)] = .unbound
        #expect(
            !GestureSeeds.longSwipesApply(base: GestureMap(), profile: profile)
        )
    }

    /// Exactly the two families the runner hands to the pan.
    @Test("focus and walk run the pan")
    func panFamilies() {
        let pan = Set(GestureFamily.allCases.filter(\.runsThePan))
        #expect(pan == [.focus, .walk])
    }
}
