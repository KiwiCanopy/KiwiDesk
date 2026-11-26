import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Screens cards' number badge (#3647 ▸ lane 2): a pick renumbers
/// the draft, the pins follow the number they hold, the pill counts
/// the renumber as ONE row whose revert takes it all back, and a
/// screen left unnumbered takes no pin.
@Suite("The Screen N badge (#3647)", .serialized)
@MainActor
struct ScreenNumberBadgeTests {
    private let a = Display(
        id: DisplayID(1),
        name: "A",
        frame: CGRect(x: 0, y: 0, width: 100, height: 100)
    )
    private let b = Display(
        id: DisplayID(2),
        name: "B",
        frame: CGRect(x: 100, y: 0, width: 100, height: 100)
    )

    private func makeModel() throws -> (KiwiCore, SettingsModel) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-3647b-\(UUID().uuidString)")
        )
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(a)
        core.state.workspaces.upsertDisplay(b)
        let model = makeTestModel(core: core)
        model.reload()
        model.config.spaces = ["1", "2"]
        model.config.spacePins = ["2": ScreenSlotKey(number: 2)!]
        model.cleanConfig = model.config
        return (core, model)
    }

    @Test("a pick swaps the numbers and the pins follow them")
    func pickSwaps() throws {
        let (_, model) = try makeModel()
        #expect(model.screenNumber(of: a) == 1)
        #expect(model.pin(of: "2") == "B:100x100")
        model.useScreenNumber(2, for: a)
        #expect(model.screenNumber(of: a) == 2)
        #expect(model.screenNumber(of: b) == 1)
        #expect(model.pin(of: "2") == "A:100x100")
        #expect(model.isDirty)
    }

    @Test("the renumber is one row, and its revert takes it all back")
    func oneRow() throws {
        let (_, model) = try makeModel()
        model.useScreenNumber(2, for: a)
        let rows = SettingsDiffRowSource.screenNumberRows(for: model)
        #expect(rows.count == 1)
        #expect(rows.first?.revert == .screenNumbers)
        #expect(model.draftChangeCount == 1)
        try model.revert(#require(rows.first))
        #expect(model.screenNumbering.draft == nil)
        #expect(!model.isDirty)
        // Picking back to the base order is no edit either.
        model.useScreenNumber(2, for: a)
        model.useScreenNumber(1, for: a)
        #expect(model.screenNumbering.draft == nil)
    }

    @Test("an unnumbered screen takes no pin, and its pins wait")
    func unnumbered() throws {
        LocalizationManager.shared.select("en")
        let (_, model) = try makeModel()
        #expect(model.canLeaveUnnumbered(b))
        model.leaveUnnumbered(b)
        #expect(model.screenNumber(of: b) == nil)
        #expect(ScreenNumberBadge.face(nil) == "Gets a new Space")
        #expect(!model.takesPins("B:100x100"))
        model.place("1", .screen("B:100x100"))
        #expect(model.config.spacePins["1"] == nil)
        #expect(model.waitingPins == ["2": 2])
        #expect(model.spacePinBadge("2") == .offline)
        #expect(model.offlinePinLabel("2") == "Screen 2 offline")
    }

    @Test("a stored target cannot leave a screen unnumbered")
    func storedTargetHasNoHole() throws {
        let (core, model) = try makeModel()
        try core.profiles.write(
            Profile(
                name: "Other",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100", "B:100x100"])
                ],
                spaces: ["1"],
                spaceModes: ["1": .bsp],
                settings: TilingSettings()
            )
        )
        model.target = .storedProfile("Other")
        model.reload()
        #expect(!model.canLeaveUnnumbered(b))
    }

    @Test("a stored target's Save stores the renumber")
    func storedSaveReorders() throws {
        let (core, model) = try makeModel()
        try core.profiles.write(
            Profile(
                name: "Other",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100", "B:100x100"])
                ],
                spaces: ["1"],
                spaceModes: ["1": .bsp],
                settings: TilingSettings()
            )
        )
        model.target = .storedProfile("Other")
        model.reload()
        model.useScreenNumber(2, for: a)
        model.saveEditedProfile()
        let saved = try core.profiles.read(name: "Other")
        #expect(
            saved.monitorSets.map(\.monitors) == [["B:100x100", "A:100x100"]]
        )
    }
}
