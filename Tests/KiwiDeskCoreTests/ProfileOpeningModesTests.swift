import Testing

@testable import KiwiDeskCore

/// What a saved profile says about its own screens (#789).
///
/// The point of the accessor is as much what it REFUSES to say as
/// what it answers: a stored profile pins spaces to fingerprints
/// and leaves Main to be resolved live, so for a multi-screen
/// profile with no pins there is no stored fact naming which
/// screen opens in what. The Settings row draws a bare outline
/// there. A version of this that guessed would put a claim about
/// behaviour on screen that loading the profile might not
/// produce — the failure `PresetScreenCard` already refuses by
/// drawing no glyph for a screen a preset plans nothing for.
@Suite("Profile opening modes (#789)")
struct ProfileOpeningModesTests {
    private func profile(
        monitors: [String],
        pins: [SpaceID: String] = [:],
        spaces: [SpaceID],
        modes: [SpaceID: LayoutMode]
    ) -> Profile {
        Profile(
            name: "p",
            monitorSets: [
                MonitorSet(monitors: monitors, spaceMonitorMap: pins)
            ],
            spaces: spaces,
            spaceModes: modes,
            settings: TilingSettings()
        )
    }

    /// The common case, and the exact one: with a single monitor
    /// every declared space is on it, so the first ordered space
    /// IS what that screen opens in — pins or no pins.
    @Test("a one-screen profile names its screen's mode")
    func oneScreenIsExact() {
        let p = profile(
            monitors: ["Studio:2560x1440"],
            spaces: [SpaceID("a"), SpaceID("b")],
            modes: [SpaceID("a"): .monocle, SpaceID("b"): .bsp]
        )
        #expect(p.openingModes() == [.monocle])
    }

    /// Order comes from the profile's own space list, never from
    /// the mode dictionary — iterating a `[SpaceID: LayoutMode]`
    /// would pick a different space between launches for one
    /// profile, and the picture would flicker between runs.
    @Test("the profile's own order decides which space is first")
    func orderIsTheProfilesOwn() {
        let p = profile(
            monitors: ["Studio:2560x1440"],
            spaces: [SpaceID("b"), SpaceID("a")],
            modes: [SpaceID("a"): .monocle, SpaceID("b"): .grid]
        )
        #expect(p.openingModes() == [.grid])
    }

    /// Pinned spaces answer for their own monitor, in the set's
    /// canonical order.
    @Test("a pinned multi-screen profile answers per monitor")
    func pinsAnswerPerMonitor() {
        let p = profile(
            monitors: ["A:1920x1080", "B:1920x1080"],
            pins: [
                SpaceID("a"): "A:1920x1080",
                SpaceID("b"): "B:1920x1080",
            ],
            spaces: [SpaceID("a"), SpaceID("b")],
            modes: [SpaceID("a"): .stack, SpaceID("b"): .grid]
        )
        #expect(p.openingModes() == [.stack, .grid])
    }

    /// The refusal, and the reason this suite exists: no pins on
    /// a multi-screen profile means no stored fact says which
    /// screen gets what, so every entry is nil and the row draws
    /// bare outlines.
    @Test("an unpinned multi-screen profile says nothing")
    func unpinnedMultiScreenSaysNothing() {
        let p = profile(
            monitors: ["A:1920x1080", "B:1920x1080"],
            spaces: [SpaceID("a"), SpaceID("b")],
            modes: [SpaceID("a"): .stack, SpaceID("b"): .grid]
        )
        #expect(p.openingModes() == [nil, nil])
    }

    /// Partial knowledge stays partial — one pinned monitor
    /// answers, the other does not, and the array carries both.
    @Test("a partly pinned profile answers only where it can")
    func partialPinsStayPartial() {
        let p = profile(
            monitors: ["A:1920x1080", "B:1920x1080"],
            pins: [SpaceID("b"): "B:1920x1080"],
            spaces: [SpaceID("a"), SpaceID("b")],
            modes: [SpaceID("a"): .stack, SpaceID("b"): .grid]
        )
        #expect(p.openingModes() == [nil, .grid])
    }

    /// One entry per covered screen, always — the row indexes
    /// this array by screen position, so a short array would draw
    /// a glyph against the wrong outline or trap.
    @Test("the array is one entry per covered screen")
    func lengthMatchesTheScreenCount() {
        for screens in 1...4 {
            let monitors = (0..<screens).map { "M\($0):1920x1080" }
            let p = profile(
                monitors: monitors,
                spaces: [SpaceID("a")],
                modes: [SpaceID("a"): .bsp]
            )
            #expect(p.openingModes().count == screens)
            #expect(p.monitorCount == screens)
        }
    }

    /// A profile with no monitor sets at all (a hand-edited or
    /// half-written file) answers with an empty array rather than
    /// trapping on a negative count.
    @Test("a profile covering no screens answers empty")
    func noScreensIsEmpty() {
        let p = Profile(
            name: "p",
            monitorSets: [],
            spaces: [SpaceID("a")],
            spaceModes: [SpaceID("a"): .bsp],
            settings: TilingSettings()
        )
        #expect(p.openingModes().isEmpty)
    }
}
