import Foundation
import Testing

@testable import KiwiDeskCore

/// `KiwiCore.savedModes(for:)` — the one-read batch the per-screen
/// quick menu asks with (#752).
///
/// Written after a `guard-prover` run found the whole method
/// untested (2026-08-17): returning `[:]` unconditionally reded
/// nothing in 3411 tests. What it has to keep apart is the
/// distinction its own docstring calls the thing that keeps a
/// phantom "not saved to profile" off the menu — **absent means
/// unknown, present-but-unlisted means the genuine `.bsp`
/// default** — and a method that answered `.bsp` for everything
/// would look identical at every call site until a user with no
/// profile met a drift subtitle.
/// `@MainActor` because `KiwiCore` is, not by choice — the work
/// itself is one JSON decode and a dictionary fill, and this suite
/// asserts nothing that needs the actor. Not `.serialized`: every
/// test builds its own core over its own temp directory, so
/// nothing here is shared to interleave.
@Suite("Saved layout modes, read in one pass (#752)")
@MainActor
struct SavedModesTests {
    /// `ProfileManager.save` sets `currentName` itself — the
    /// field is `private(set)`, and saving IS how a profile
    /// becomes the active one, so no test needs to reach past it.
    private func profile(
        named name: String,
        modes: [SpaceID: LayoutMode]
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaces: Array(modes.keys),
            spaceModes: modes,
            settings: TilingSettings()
        )
    }

    @Test("No active profile answers nothing, never a default")
    func noProfileIsUnknown() {
        let core = makeTestCore()
        #expect(core.profiles.currentName == nil)
        // Empty, not `[1: .bsp]`. A caller reading a `.bsp` here
        // would compare it against the live mode and claim drift
        // on a space with no profile behind it at all.
        #expect(core.savedModes(for: [SpaceID("1")]).isEmpty)
    }

    @Test("A listed space answers what the profile saved")
    func listedSpaceAnswersItsSavedMode() throws {
        let core = makeTestCore()
        try core.profiles.save(
            profile(
                named: "p",
                modes: [SpaceID("1"): .grid, SpaceID("2"): .monocle]
            )
        )

        let modes = core.savedModes(
            for: [SpaceID("1"), SpaceID("2")]
        )
        #expect(modes[SpaceID("1")] == .grid)
        #expect(modes[SpaceID("2")] == .monocle)
    }

    @Test("An unlisted space in a readable profile is .bsp")
    func unlistedSpaceIsTheDefault() throws {
        let core = makeTestCore()
        try core.profiles.save(
            profile(named: "p", modes: [SpaceID("1"): .grid])
        )

        let modes = core.savedModes(
            for: [SpaceID("1"), SpaceID("9")]
        )
        // Present with the default, NOT absent: the profile is
        // readable and simply says nothing about space 9, which is
        // the genuine `.bsp` default rather than "unknown". The
        // two conditions have to stay distinguishable, which is
        // the whole reason this returns a sparse dictionary.
        #expect(modes[SpaceID("9")] == .bsp)
        #expect(modes.keys.contains(SpaceID("9")))
    }

    @Test("An unreadable profile answers nothing")
    func unreadableProfileIsUnknown() throws {
        let core = makeTestCore()
        try core.profiles.save(
            profile(named: "p", modes: [SpaceID("1"): .grid])
        )
        // Corrupt the JSON on disk, the way #123's unreadable-
        // profile arm does: the name still resolves, the read
        // fails.
        try "not json".write(
            to: core.profiles.directory
                .appendingPathComponent("p.json"),
            atomically: true,
            encoding: .utf8
        )

        #expect(core.savedModes(for: [SpaceID("1")]).isEmpty)
    }

    @Test("Asking for nothing answers nothing, without reading")
    func emptyRequestIsEmpty() throws {
        let core = makeTestCore()
        try core.profiles.save(
            profile(named: "p", modes: [SpaceID("1"): .grid])
        )

        #expect(core.savedModes(for: []).isEmpty)
    }

    @Test("One read answers every space asked about")
    func oneReadAnswersAll() throws {
        let core = makeTestCore()
        let spaces = (1...5).map { SpaceID("\($0)") }
        try core.profiles.save(
            profile(
                named: "p",
                modes: Dictionary(
                    uniqueKeysWithValues: spaces.map {
                        ($0, LayoutMode.grid)
                    }
                )
            )
        )

        // The reason this method exists rather than calling the
        // single-space one per screen: five answers, one decode.
        let modes = core.savedModes(for: spaces)
        #expect(modes.count == spaces.count)
        #expect(modes.values.allSatisfy { $0 == .grid })
    }
}
