import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The tour's "Start with" doors (#3294): which offered layout the
/// desk still is, the Continue on an untouched desk (a preset copy,
/// the replaced copy deleted), and the in-place replace on a changed
/// desk with its Revert.
@Suite("Tour start and Spaces replace (#3294)", .serialized)
@MainActor
struct TourStartReplaceTests {
    private func makeCore(screens: Int = 1) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-tour-\(UUID().uuidString)")
        )
        try? core.guiConfigStore.save(GuiConfig())
        for index in 0..<screens {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: "Desk \(index + 1)",
                    frame: CGRect(
                        x: CGFloat(index) * 2560,
                        y: 0,
                        width: 2560,
                        height: 1440
                    )
                )
            )
        }
        return core
    }

    private var offered: [StandardLayout] {
        [StandardProfiles.developer1, StandardProfiles.focus1]
    }

    @Test("the copy this tour saved is its preset while untouched")
    func untouchedCopyIsItsPreset() throws {
        let core = makeCore()
        let copy = try core.startTour(
            with: StandardProfiles.developer1,
            replacing: nil
        )
        #expect(
            core.tourDesk(among: offered, copy: copy)
                == .untouched(StandardProfiles.developer1)
        )
    }

    /// Anything of the user's in the copy — here a setting — makes
    /// it theirs, so no pick deletes it.
    @Test("an edited copy is the user's desk")
    func editedCopyIsChanged() throws {
        let core = makeCore()
        let copy = try core.startTour(
            with: StandardProfiles.developer1,
            replacing: nil
        )
        var profile = try core.profiles.read(name: "Developer")
        profile.settings.gapsGlobal = .uniform(17)
        try core.profiles.write(profile)
        #expect(core.tourDesk(among: offered, copy: copy) == .changed)
    }

    @Test("a preset copy from before this tour is the user's desk")
    func earlierCopyIsChanged() throws {
        let core = makeCore()
        try core.applyStandard(StandardProfiles.developer1)
        #expect(core.tourDesk(among: offered, copy: nil) == .changed)
    }

    /// A profile live on screens it keeps no layout for (the
    /// count's default) cannot record a replace's screens: it is
    /// left as saved and a pick starts a copy.
    @Test("a profile with no layout for these screens is foreign")
    func foreignScreens() throws {
        let core = makeCore()
        try core.applyStandard(StandardProfiles.developer1)
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "Other",
                frame: CGRect(x: 0, y: 0, width: 1728, height: 1117)
            )
        )
        #expect(core.tourDesk(among: offered, copy: nil) == .foreign)
    }

    @Test("no saved profile live replaces nothing")
    func nothingSavedIsUnsaved() {
        let core = makeCore()
        #expect(core.tourDesk(among: offered, copy: nil) == .unsaved)
    }

    @Test("a Continue swaps an untouched copy, never piling them up")
    func startReplacesTheCopy() throws {
        let core = makeCore()
        let copy = try core.startTour(
            with: StandardProfiles.developer1,
            replacing: nil
        )
        let next = try core.startTour(
            with: StandardProfiles.focus1,
            replacing: copy
        )
        #expect(next?.profile.name == "Focus")
        #expect(core.profiles.currentName == "Focus")
        #expect(core.profiles.list().contains("Focus"))
        #expect(!core.profiles.list().contains("Developer"))
    }

    /// A copy changed since this tour saved it — here while another
    /// profile is live — is no longer the tour's to delete.
    @Test("a copy edited since it was saved is kept")
    func editedCopyIsKept() throws {
        let core = makeCore()
        let copy = try core.startTour(
            with: StandardProfiles.developer1,
            replacing: nil
        )
        var profile = try core.profiles.read(name: "Developer")
        profile.settings.gapsGlobal = .uniform(17)
        try core.profiles.write(profile)
        try core.startTour(with: StandardProfiles.focus1, replacing: copy)
        #expect(core.profiles.list().contains("Developer"))
    }

    /// The tour's own later write (the look) leaves its copy the
    /// tour's, once re-read.
    @Test("a re-read copy is untouched after the tour's own write")
    func rereadCopyStaysUntouched() throws {
        let core = makeCore()
        let saved = try core.startTour(
            with: StandardProfiles.developer1,
            replacing: nil
        )
        var profile = try core.profiles.read(name: "Developer")
        profile.settings.gapsGlobal = .uniform(9)
        try core.profiles.write(profile)
        let copy = try #require(saved.flatMap(core.tourCopyRead))
        #expect(
            core.tourDesk(among: offered, copy: copy)
                == .untouched(StandardProfiles.developer1)
        )
    }

    /// Five screens take the four-screen presets, a Space more on
    /// the fifth; the picture and the apply agree.
    @Test("a desk past four screens takes a four-screen preset")
    func fiveScreensStart() throws {
        let core = makeCore(screens: 5)
        let layout = StandardProfiles.developer4
        let plan = core.tourPlan(for: layout)
        #expect(plan.count == 5)
        try core.startTour(with: layout, replacing: nil)
        let live = core.state.workspaces.allSpaces.map(\.id.raw)
        #expect(live.count == layout.spaceCount + 1)
        let drawn = plan.flatMap(\.spaces).map(\.id.raw)
        #expect(Set(drawn) == Set(live))
        // The fifth screen, past the plan, takes the starter's
        // single-Space rule: a desktop's order Grid · Stack · BSP ·
        // Scrolling, the one Developer places least — BSP.
        let fifth = SpaceID(layout.spaceCount + 1)
        #expect(core.state.workspaces[fifth]?.mode == .bsp)
    }

    /// Pins on the live screens follow a replace, and the Revert
    /// puts every set's pins back.
    @Test("a two-screen replace and Revert keep the pins")
    func twoScreenPins() throws {
        let core = makeCore(screens: 2)
        try core.applyStandard(StandardProfiles.developer2)
        let before = try core.profiles.read(name: "Developer")
        let baseline = try #require(core.tourSpacesBaseline())
        #expect(core.replaceSpaces(with: StandardProfiles.focus2))
        let replaced = try core.profiles.read(name: "Developer")
        let planned = try #require(
            core.spaceSet(for: StandardProfiles.focus2)
        )
        #expect(
            replaced.monitorSets.first?.spaceMonitorMap == planned.pins
        )
        #expect(!planned.pins.isEmpty)
        #expect(core.restoreSpaces(baseline))
        let restored = try core.profiles.read(name: "Developer")
        #expect(restored.monitorSets == before.monitorSets)
        #expect(restored.orderedSpaces == before.orderedSpaces)
    }

    @Test("a replace keeps the profile and changes only its Spaces")
    func replaceInPlace() throws {
        let core = makeCore()
        try core.applyStandard(StandardProfiles.developer1)
        var before = try core.profiles.read(name: "Developer")
        before.settings.gapsGlobal = .uniform(17)
        before.appRules = AppRuleOverride(rules: ["MAIL": nil])
        try core.profiles.write(before)
        let id = before.id
        let baseline = try #require(core.tourSpacesBaseline())
        #expect(core.replaceSpaces(with: StandardProfiles.focus1))
        let after = try core.profiles.read(name: "Developer")
        #expect(after.id == id)
        #expect(after.orderedSpaces == ["1", "2"])
        #expect(after.spaceModes["1"] == .scrolling)
        #expect(after.settings.gapsGlobal == .uniform(17))
        #expect(after.appRules == before.appRules)
        #expect(after.layers == before.layers)
        #expect(core.profiles.currentName == "Developer")
        #expect(core.state.workspaces.allSpaces.map(\.id) == ["1", "2"])
        // The step's Revert puts the saved Spaces back.
        #expect(core.restoreSpaces(baseline))
        let restored = try core.profiles.read(name: "Developer")
        #expect(restored.orderedSpaces == ["1", "2", "3", "4"])
        #expect(restored.spaceModes["1"] == .stack)
    }

    @Test("a Revert is refused once another profile is live")
    func revertRefusedElsewhere() throws {
        let core = makeCore()
        try core.applyStandard(StandardProfiles.developer1)
        let baseline = try #require(core.tourSpacesBaseline())
        try core.applyStandard(StandardProfiles.focus1)
        #expect(!core.restoreSpaces(baseline))
    }

    @Test("app rules aiming at a dropped Space are counted")
    func rulesLeftBehind() throws {
        let core = makeCore()
        try core.applyStandard(StandardProfiles.developer1)
        core.state.appRules = ["mail": "4", "notes": "1", "chat": "4"]
        let set = try #require(core.spaceSet(for: StandardProfiles.focus1))
        #expect(core.appRulesLeftBehind(by: set) == ["4": 2])
    }
}
