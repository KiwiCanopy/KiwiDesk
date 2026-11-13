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
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-tour-\(UUID().uuidString)")
        )
        try? core.guiConfigStore.save(GuiConfig())
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "Desk",
                frame: CGRect(x: 0, y: 0, width: 2560, height: 1440)
            )
        )
        return core
    }

    private var offered: [StandardLayout] {
        [StandardProfiles.developer1, StandardProfiles.focus1]
    }

    @Test("an untouched preset copy is that preset")
    func untouchedCopyIsItsPreset() throws {
        let core = makeCore()
        try core.applyStandard(StandardProfiles.developer1)
        #expect(
            core.untouchedTourChoice(among: offered)
                == StandardProfiles.developer1
        )
    }

    @Test("a changed desk is no offered layout")
    func changedDeskIsNone() throws {
        let core = makeCore()
        try core.applyStandard(StandardProfiles.developer1)
        var profile = try core.profiles.read(name: "Developer")
        profile.spaceModes["1"] = .bsp
        try core.profiles.write(profile)
        #expect(core.untouchedTourChoice(among: offered) == nil)
    }

    @Test("a Continue swaps an untouched copy, never piling them up")
    func startReplacesTheCopy() throws {
        let core = makeCore()
        try core.applyStandard(StandardProfiles.developer1)
        let live = try core.startTour(
            with: StandardProfiles.focus1,
            replacing: StandardProfiles.developer1
        )
        #expect(live == "Focus")
        #expect(core.profiles.list().contains("Focus"))
        #expect(!core.profiles.list().contains("Developer"))
    }

    @Test("a replace keeps the profile and changes only its Spaces")
    func replaceInPlace() throws {
        let core = makeCore()
        try core.applyStandard(StandardProfiles.developer1)
        var before = try core.profiles.read(name: "Developer")
        before.settings.gapsGlobal = .uniform(17)
        try core.profiles.write(before)
        let id = before.id
        let baseline = try #require(core.tourSpacesBaseline())
        #expect(core.replaceSpaces(with: StandardProfiles.focus1))
        let after = try core.profiles.read(name: "Developer")
        #expect(after.id == id)
        #expect(after.orderedSpaces == ["1", "2"])
        #expect(after.spaceModes["1"] == .scrolling)
        #expect(after.settings.gapsGlobal == .uniform(17))
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
