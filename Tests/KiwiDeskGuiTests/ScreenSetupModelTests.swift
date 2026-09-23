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
}
