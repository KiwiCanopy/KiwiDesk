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
        mainSpaces: [SpaceID] = [],
        spaces: [SpaceID],
        modes: [SpaceID: LayoutMode]
    ) -> Profile {
        Profile(
            name: "p",
            monitorSets: [
                MonitorSet(monitors: monitors, spaceMonitorMap: pins)
            ],
            mainSpaces: mainSpaces,
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

    /// #959: an ordinary two-screen profile drew ONE glyph and
    /// one blank pip. Saving pins only the spaces that are not
    /// on the main display, so the main monitor is exactly the
    /// covered one with no pin — and the follows-main spaces
    /// have nowhere else to be. The answer is elimination, not a
    /// guess about which monitor is Main.
    @Test("the sole unpinned screen answers from Main")
    func soleUnpinnedScreenAnswersFromMain() {
        let p = profile(
            monitors: ["A:1920x1080", "B:1920x1080"],
            pins: [SpaceID("b"): "B:1920x1080"],
            mainSpaces: [SpaceID("a")],
            spaces: [SpaceID("a"), SpaceID("b")],
            modes: [SpaceID("a"): .stack, SpaceID("b"): .grid]
        )
        #expect(p.openingModes() == [.stack, .grid])
    }

    /// The refusal survives the fix: with TWO monitors carrying
    /// no pin the follows-main spaces fit on either, so naming
    /// one would be the guess this accessor exists to refuse.
    @Test("two unpinned screens stay blank even with Main")
    func twoUnpinnedScreensStayBlank() {
        let p = profile(
            monitors: [
                "A:1920x1080", "B:1920x1080", "C:1920x1080",
            ],
            pins: [SpaceID("c"): "C:1920x1080"],
            mainSpaces: [SpaceID("a")],
            spaces: [SpaceID("a"), SpaceID("b"), SpaceID("c")],
            modes: [
                SpaceID("a"): .stack,
                SpaceID("b"): .monocle,
                SpaceID("c"): .grid,
            ]
        )
        #expect(p.openingModes() == [nil, nil, .grid])
    }

    /// Which follows-main space is FIRST is the profile's own
    /// order, never `mainSpaces`' — that list is stored sorted
    /// by raw id, so reading it directly would name "s1" on a
    /// profile whose list opens with "s2".
    @Test("Main's first space is the profile's order, not sorted")
    func mainFirstSpaceFollowsTheProfilesOrder() {
        let p = profile(
            monitors: ["A:1920x1080", "B:1920x1080"],
            pins: [SpaceID("z"): "B:1920x1080"],
            mainSpaces: [SpaceID("s1"), SpaceID("s2")],
            spaces: [SpaceID("s2"), SpaceID("s1"), SpaceID("z")],
            modes: [
                SpaceID("s1"): .bsp,
                SpaceID("s2"): .monocle,
                SpaceID("z"): .grid,
            ]
        )
        #expect(p.openingModes() == [.monocle, .grid])
    }

    /// A pinned monitor keeps answering from its own pin — the
    /// elimination arm may only fill a screen that had NO answer,
    /// never overwrite one.
    @Test("elimination never overwrites a pinned screen")
    func eliminationOnlyFillsTheBlank() {
        let p = profile(
            monitors: ["A:1920x1080", "B:1920x1080"],
            pins: [
                SpaceID("a"): "A:1920x1080",
                SpaceID("b"): "B:1920x1080",
            ],
            mainSpaces: [SpaceID("m")],
            spaces: [SpaceID("m"), SpaceID("a"), SpaceID("b")],
            modes: [
                SpaceID("m"): .scrolling,
                SpaceID("a"): .stack,
                SpaceID("b"): .grid,
            ]
        )
        #expect(p.openingModes() == [.stack, .grid])
    }
}
