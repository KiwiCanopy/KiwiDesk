import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-setups-\(UUID().uuidString)"
            )
    )
}

/// Replaces the connected screens with 100x100 ones named `names`.
@MainActor
private func connect(_ core: KiwiCore, _ names: [String]) {
    for display in core.state.workspaces.allDisplays {
        core.state.workspaces.removeDisplay(display.id)
    }
    for (index, name) in names.enumerated() {
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(UInt32(index + 1)),
                name: name,
                frame: CGRect(
                    x: CGFloat(index) * 100,
                    y: 0,
                    width: 100,
                    height: 100
                )
            )
        )
    }
}

/// What the Profiles page's screen-setup row draws and offers
/// (#1530): the label of a setup whose screens are not connected,
/// and the `+` menu's contents and order.
@Suite("Profiles page screen setups (#1530)", .serialized)
@MainActor
struct ScreenSetupModelTests {
    @Test("A disconnected screen reads by its name, not its size")
    func disconnectedScreenName() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let model = makeTestModel(core: makeCore())
        #expect(
            model.setupLabel(["Studio Display:2560x1440"])
                == "Studio Display"
        )
        #expect(
            model.setupLabel(["Studio Display:2560x1440"], sized: true)
                == "Studio Display (2560x1440)"
        )
        // The size is after the LAST colon; a name may hold one.
        #expect(
            model.setupLabel(["Dell: U2723:2560x1440"])
                == "Dell: U2723"
        )
    }

    @Test("Two setups that would read alike keep their sizes")
    func sameNamedSetupsAreSized() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let model = makeTestModel(core: makeCore())
        let labels = model.setupLabels([
            ["LG:1920x1080"],
            ["LG:2560x1440"],
            ["Dell:1920x1080"],
        ])
        #expect(labels == ["LG (1920x1080)", "LG (2560x1440)", "Dell"])
    }

    @Test("The + offers other profiles' setups, connected first")
    func plusOffersOthersConnectedFirst() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        connect(core, ["B"])
        try core.persistProfile(named: "Alpha", modes: nil)
        connect(core, ["C"])
        try core.persistProfile(named: "Home", modes: nil)
        connect(core, ["A"])
        let model = makeTestModel(core: core)
        model.refreshProfiles()
        let choices = model.claimableSetups(for: "Home")
        // Home's own C is not offered; the connected A leads, then
        // Alpha's B by owner name.
        #expect(
            choices.map(\.monitors) == [["A:100x100"], ["B:100x100"]]
        )
        #expect(choices.first?.isConnected == true)
        #expect(choices.first?.owner == "Work")
        #expect(choices.last?.owner == "Alpha")
    }

    @Test("Picking a setup moves it and refreshes the rows")
    func pickMovesTheSetup() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Work", modes: nil)
        connect(core, ["B"])
        try core.persistProfile(named: "Home", modes: nil)
        let model = makeTestModel(core: core)
        model.refreshProfiles()
        model.claimScreenSetup(["A:100x100"], for: "Home")
        let work = model.profileSummaries.first { $0.name == "Work" }
        #expect(work?.isDormant == true)
        let home = model.profileSummaries.first { $0.name == "Home" }
        #expect(home?.sets.count == 2)
    }

    /// A pick onto the loaded profile moves the LIVE pins, and an
    /// unedited Live draft follows — or its next Save would write
    /// the old pins back.
    @Test("An unedited draft follows the pins a pick leaves live")
    func draftFollowsPickedPins() throws {
        let core = makeCore()
        connect(core, ["A", "B"])
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.spacePins = ["2": "B:100x100"]
        try core.persistProfile(named: "Work", modes: nil)
        try core.persistProfile(named: "Home", modes: nil)
        try core.loadProfile(named: "Work")
        let model = makeTestModel(core: core)
        model.refreshProfiles()
        let pair = ["A:100x100", "B:100x100"]
        model.claimScreenSetup(pair, for: "Home")
        model.config.spacePins = [:]
        model.cleanConfig.spacePins = [:]
        core.spacePins = [:]
        model.claimScreenSetup(pair, for: "Work")
        #expect(core.livePins == ["2": "B:100x100"])
        #expect(model.config.spacePins == core.livePins)
        #expect(model.cleanConfig.spacePins == core.livePins)
    }

    /// The rebase follows an UNEDITED draft only: a pin the user
    /// has edited and not saved is theirs, and only the baseline
    /// moves under it.
    @Test("An edited draft keeps its pins across a pick")
    func editedDraftKeepsPins() throws {
        let core = makeCore()
        connect(core, ["A", "B"])
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.spacePins = ["2": "B:100x100"]
        try core.persistProfile(named: "Work", modes: nil)
        try core.persistProfile(named: "Home", modes: nil)
        try core.loadProfile(named: "Work")
        let model = makeTestModel(core: core)
        model.refreshProfiles()
        let pair = ["A:100x100", "B:100x100"]
        model.claimScreenSetup(pair, for: "Home")
        let edited: [SpaceID: String] = ["1": "A:100x100"]
        model.config.spacePins = edited
        model.cleanConfig.spacePins = [:]
        model.claimScreenSetup(pair, for: "Work")
        #expect(model.config.spacePins == edited)
        #expect(model.cleanConfig.spacePins == core.livePins)
    }

    @Test("Home names a default that can load, never a dormant one")
    func homeNamesAUsableDefault() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let core = makeCore()
        try core.profiles.write(
            Profile(
                name: "Resting",
                monitorSets: [],
                monitorCount: 1,
                isDefault: true,
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        let model = makeTestModel(core: core)
        model.refreshProfiles()
        #expect(
            HomeCardContent.subtitle(for: .profiles, model: model)
                == "1 saved"
        )
    }

    /// Two same-named setups held by DIFFERENT profiles read
    /// alike on one page, so each is sized even in a list where it
    /// is alone (owner, 2026-09-23: two Sidecar resolutions).
    @Test("A lookalike held elsewhere on the page keeps the size")
    func lookalikeAcrossProfilesIsSized() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let core = makeCore()
        connect(core, ["Sidecar"])
        try core.persistProfile(named: "Vision", modes: nil)
        core.state.workspaces.removeDisplay(DisplayID(1))
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "Sidecar",
                frame: CGRect(x: 0, y: 0, width: 200, height: 100)
            )
        )
        try core.persistProfile(named: "Wide", modes: nil)
        let model = makeTestModel(core: core)
        model.refreshProfiles()
        #expect(
            model.setupLabels([["Sidecar:100x100"]])
                == ["Sidecar (100x100)"]
        )
    }

    /// A profile a binding put on screens ANOTHER profile owns has
    /// nothing to save there, so no "Screens" row appears (#1530).
    @Test("An owned setup is no unsaved Screens change")
    func ownedSetupIsNoDrift() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Starter", modes: nil)
        connect(core, ["V"])
        try core.persistProfile(named: "Vision", modes: nil)
        core.apply(
            profile: try core.profiles.read(name: "Starter"),
            cause: .event
        )
        let model = makeTestModel(core: core)
        model.refreshProfiles()
        #expect(model.profileDirty)
        #expect(model.profileDrift == nil)
        // Unowned screens are still the profile's to save.
        connect(core, ["N"])
        core.apply(
            profile: try core.profiles.read(name: "Starter"),
            cause: .event
        )
        model.refreshProfiles()
        #expect(model.profileDrift == .screensUnsaved(profile: "Starter"))
    }
}
