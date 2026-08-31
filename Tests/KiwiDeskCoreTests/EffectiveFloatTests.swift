import Testing

@testable import KiwiDeskCore

/// The one predicate every float safety net asks (#500, #1178).
///
/// It used to be `FloatReanchor.eligible`, which only the
/// display-crossing re-anchor read, plus an inline disjunction in
/// the stash — and the bar clamp, asking the FLAG alone, left a
/// `.floating` space's windows under the strip permanently.
@Suite("Effective float")
struct EffectiveFloatTests {
    @Test("The flag alone floats, in any mode")
    func flagFloatsAnywhere() {
        #expect(
            EffectiveFloat.applies(isFloating: true, mode: .bsp)
        )
        #expect(
            EffectiveFloat.applies(isFloating: true, mode: nil)
        )
    }

    @Test("A floating-mode space floats its members")
    func floatingModeFloatsItsMembers() {
        // That layout assigns no frames, so nothing else will
        // ever place these windows — which is what makes every
        // float net theirs.
        #expect(
            EffectiveFloat.applies(
                isFloating: false,
                mode: .floating
            )
        )
    }

    @Test("A tiled window in a tiling space is not floating")
    func tiledIsNotFloating() {
        #expect(
            !EffectiveFloat.applies(
                isFloating: false,
                mode: .track
            )
        )
        // An unknown space cannot claim the exemption: a caller
        // that cannot name the mode has not shown a float.
        #expect(
            !EffectiveFloat.applies(
                isFloating: false,
                mode: nil
            )
        )
    }
}
