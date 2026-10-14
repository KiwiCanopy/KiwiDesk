import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's appearance while on (#2103 ruling 7): the switch
/// happens only where the system differs, the way back only where
/// KiwiVision made the switch and nobody changed it since, and an
/// unpaid switch is paid by the next stop or start.
@Suite("KiwiVision appearance while on")
@MainActor
struct KiwiVisionAppearanceTests {
    /// A system appearance the test drives, recording every ask.
    @MainActor
    final class FakeSystem {
        var state = SystemAppearance.State(dark: false, auto: false)
        var asked: [Bool] = []
        var rearms = 0
        var debt: VisionAppearanceDebt?
        var refusesDebt = false

        var machine: VisionAppearanceSwitch {
            VisionAppearanceSwitch(
                read: { self.state },
                setDark: {
                    self.asked.append($0)
                    // A manual switch turns automatic switching off.
                    self.state = .init(dark: $0, auto: false)
                },
                rearmAuto: {
                    self.rearms += 1
                    self.state.auto = true
                },
                readDebt: { self.debt },
                writeDebt: {
                    guard !self.refusesDebt else { return false }
                    self.debt = $0
                    return true
                }
            )
        }
    }

    private func makeCore(_ system: FakeSystem) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-appearance-\(UUID().uuidString)"
                )
        )
        core.eventLoop.ownKeyWindow = { nil }
        core.vision.appearanceSwitch = system.machine
        return core
    }

    private func ask(_ core: KiwiCore, _ raw: String) -> Bool {
        core.execute("kiwivision.set_appearance", args: [.string(raw)])
            .isSuccess
    }

    @Test("unchanged, the default, never switches")
    func unchangedNeverSwitches() {
        let system = FakeSystem()
        let core = makeCore(system)
        core.setKiwiVision(true)
        core.setKiwiVision(false)
        #expect(system.asked.isEmpty)
        #expect(system.debt == nil)
    }

    @Test("on switches where it differs, off switches back")
    func roundTrip() {
        let system = FakeSystem()
        let core = makeCore(system)
        #expect(ask(core, "dark"))
        #expect(system.asked.isEmpty, "off: the ask waits for on")
        core.setKiwiVision(true)
        #expect(system.asked == [true])
        #expect(
            system.debt
                == VisionAppearanceDebt(
                    found: .init(dark: false, auto: false),
                    setDark: true
                )
        )
        core.setKiwiVision(false)
        #expect(system.asked == [true, false])
        #expect(system.debt == nil)
    }

    @Test("opposite takes whichever the system is not showing")
    func oppositeFlips() {
        for startsDark in [false, true] {
            let system = FakeSystem()
            system.state.dark = startsDark
            let core = makeCore(system)
            _ = ask(core, "opposite")
            core.setKiwiVision(true)
            #expect(system.asked == [!startsDark])
            core.setKiwiVision(false)
            #expect(system.asked == [!startsDark, startsDark])
            #expect(system.debt == nil)
        }
    }

    @Test("an appearance already shown is left alone, both ways")
    func alreadyShownIsLeft() {
        let system = FakeSystem()
        system.state.dark = true
        let core = makeCore(system)
        _ = ask(core, "dark")
        core.setKiwiVision(true)
        core.setKiwiVision(false)
        #expect(system.asked.isEmpty)
        #expect(system.debt == nil)
    }

    @Test("a manual change while on is kept")
    func manualChangeIsKept() {
        let system = FakeSystem()
        let core = makeCore(system)
        _ = ask(core, "dark")
        core.setKiwiVision(true)
        system.state.dark = false  // the user switched back by hand
        core.setKiwiVision(false)
        #expect(system.asked == [true])
        #expect(system.debt == nil)
    }

    @Test("automatic switching comes back where it was on")
    func autoIsRearmed() {
        let system = FakeSystem()
        system.state.auto = true
        let core = makeCore(system)
        _ = ask(core, "dark")
        core.setKiwiVision(true)
        #expect(system.debt?.found.auto == true)
        core.setKiwiVision(false)
        #expect(system.asked == [true, false])
        #expect(system.rearms == 1)
        #expect(system.state == .init(dark: false, auto: true))
    }

    @Test("no debt stored, no switch")
    func refusedDebtRefusesTheSwitch() {
        let system = FakeSystem()
        system.refusesDebt = true
        let core = makeCore(system)
        _ = ask(core, "dark")
        core.setKiwiVision(true)
        #expect(system.asked.isEmpty)
    }

    @Test("a new ask while on pays the old switch first")
    func askWhileOn() {
        let system = FakeSystem()
        let core = makeCore(system)
        _ = ask(core, "dark")
        core.setKiwiVision(true)
        _ = ask(core, "light")
        // Paid back to light, which `light` then finds shown.
        #expect(system.asked == [true, false])
        #expect(system.debt == nil)
        _ = ask(core, "dark")
        #expect(system.asked == [true, false, true])
        #expect(system.debt?.setDark == true)
    }

    @Test("a debt left by a quit or crash is paid by the next core")
    func leftoverDebtIsPaid() {
        let system = FakeSystem()
        system.state.dark = true
        system.debt = VisionAppearanceDebt(
            found: .init(dark: false, auto: false),
            setDark: true
        )
        let core = makeCore(system)
        core.payVisionAppearanceDebt()
        #expect(system.asked == [false])
        #expect(system.debt == nil)
    }

    @Test("the verb refuses a value it does not know")
    func verbRefuses() {
        let core = makeCore(FakeSystem())
        let reply = core.execute(
            "kiwivision.set_appearance",
            args: [.string("dusk")]
        )
        #expect(!reply.isSuccess)
        #expect(
            reply == CommandResponse.expected(VisionAppearance.self)
        )
    }
}
