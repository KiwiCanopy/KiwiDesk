import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A Space pinned to a screen number no connected screen holds
/// (#3689): its Screen menu selects that pin, never Automatic, and
/// writing the menu's own selection back keeps the stored number.
@Suite("A waiting pin's Screen menu (#3689)", .serialized)
@MainActor
struct WaitingScreenPinMenuTests {
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

    /// Two screens; Space "mail" pinned to Screen 3.
    private func makeModel() -> SettingsModel {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-3689-\(UUID().uuidString)")
        )
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(a)
        core.state.workspaces.upsertDisplay(b)
        let model = makeTestModel(core: core)
        model.reload()
        model.config.spaces = ["mail"]
        model.config.spacePins = ["mail": ScreenSlotKey(number: 3)!]
        model.cleanConfig = model.config
        return model
    }

    @Test("the menu selects the waiting number, offered once")
    func selectsWaitingNumber() throws {
        LocalizationManager.shared.select("en")
        let model = makeModel()
        let slot = try #require(ScreenSlotKey(number: 3))
        let choice = model.screenChoice(of: "mail")
        #expect(choice == .waiting(slot))
        #expect(choice.title(in: model) == "Screen 3 offline")
        let offered = SpaceScreenChoice.offered(for: "mail", in: model)
        let matches = offered.filter { $0 == choice }
        #expect(matches.count == 1)
    }

    @Test("writing the selection back keeps the stored number")
    func reselectKeepsPin() {
        let model = makeModel()
        // The Picker's binding writes its selection through `place`.
        model.place("mail", model.screenChoice(of: "mail"))
        #expect(model.config.spacePins["mail"] == ScreenSlotKey(number: 3))
        #expect(model.config == model.cleanConfig)
    }

    @Test("an area pin waits whole, its area id kept")
    func areaPinWaits() throws {
        LocalizationManager.shared.select("en")
        let model = makeModel()
        let slot = try #require(ScreenSlotKey(number: 3, areaID: 2))
        model.config.spacePins = ["mail": slot]
        model.cleanConfig = model.config
        let choice = model.screenChoice(of: "mail")
        #expect(choice == .waiting(slot))
        #expect(choice.title(in: model) == "Screen 3 offline")
        model.place("mail", choice)
        #expect(model.config.spacePins["mail"] == slot)
    }

    @Test("Follows main outranks a waiting pin, as the runtime does")
    func followsMainOutranks() {
        let model = makeModel()
        model.config.mainSpaces = ["mail"]
        #expect(model.screenChoice(of: "mail") == .followsMain)
    }

    @Test("a screen left unnumbered makes its pins wait the same way")
    func unnumberedScreenWaits() throws {
        LocalizationManager.shared.select("en")
        let model = makeModel()
        model.config.spacePins = ["mail": ScreenSlotKey(number: 2)!]
        model.cleanConfig = model.config
        model.leaveUnnumbered(b)
        let slot = try #require(ScreenSlotKey(number: 2))
        let choice = model.screenChoice(of: "mail")
        #expect(choice == .waiting(slot))
        #expect(choice.title(in: model) == model.offlinePinLabel("mail"))
        model.place("mail", choice)
        #expect(model.config.spacePins["mail"] == slot)
    }
}
