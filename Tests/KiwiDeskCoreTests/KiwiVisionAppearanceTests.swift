import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's appearance while on (#2103 ruling 7): every move is
/// one transition of one ledger, judged against the appearance the
/// debt FOUND — the switch happens only where the system differs,
/// the way back only for a switch nobody changed since, a reload
/// moves nothing, and an unpaid switch waits for the next start.
@Suite("KiwiVision appearance while on")
@MainActor
struct KiwiVisionAppearanceTests {
    /// A system appearance the test drives. `lands` false keeps an
    /// ask queued until `land()`, as the System Events fallback does.
    @MainActor
    final class FakeSystem {
        var state = SystemAppearance.State(dark: false, auto: false)
        var asked: [Bool] = []
        var queued: [Bool] = []
        var lands = true
        var rearms = 0
        var debt: VisionAppearanceDebt?
        var refusesDebt = false

        /// Lands every queued ask, in order.
        func land() {
            for dark in queued { state = .init(dark: dark, auto: false) }
            queued.removeAll()
        }

        var machine: VisionAppearanceSwitch {
            VisionAppearanceSwitch(
                read: { self.state },
                setDark: {
                    self.asked.append($0)
                    self.queued.append($0)
                    // A manual switch turns automatic switching off.
                    if self.lands { self.land() }
                    return self.lands
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

    private static let start = Date(timeIntervalSince1970: 1_000_000)

    private func makeCore(
        _ system: FakeSystem,
        clock: @escaping () -> Date = { start }
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-appearance-\(UUID().uuidString)"
                )
        )
        core.eventLoop.ownKeyWindow = { nil }
        core.vision.appearanceSwitch = system.machine
        core.wallClock = clock
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
        #expect(system.debt?.found == .init(dark: false, auto: false))
        #expect(system.debt?.setDark == true)
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

    @Test("a manual change while on is kept, once ours had landed")
    func manualChangeIsKept() {
        var now = Self.start
        let system = FakeSystem()
        let core = makeCore(system) { now }
        _ = ask(core, "dark")
        core.setKiwiVision(true)
        now += VisionAppearanceDebt.settleBound
        system.state.dark = false  // the user switched back by hand
        core.setKiwiVision(false)
        #expect(system.asked == [true])
        #expect(system.debt == nil)
    }

    @Test("a reload repeating the ask moves nothing")
    func repeatedAskMovesNothing() {
        let system = FakeSystem()
        let core = makeCore(system)
        _ = ask(core, "dark")
        core.setKiwiVision(true)
        _ = ask(core, "dark")
        core.retargetVisionAppearance(.dark)
        #expect(system.asked == [true])
    }

    @Test("a repeated ask leaves a manual change alone")
    func repeatedAskKeepsTheManualChange() {
        var now = Self.start
        let system = FakeSystem()
        let core = makeCore(system) { now }
        _ = ask(core, "dark")
        core.setKiwiVision(true)
        now += VisionAppearanceDebt.settleBound
        system.state.dark = false  // the user switched back by hand
        _ = ask(core, "dark")  // e.g. a reload re-running init.lua
        #expect(system.asked == [true])
        #expect(system.state.dark == false)
    }

    @Test("a new ask is judged against the appearance found")
    func newAskJudgesTheFound() {
        let system = FakeSystem()
        system.lands = false  // nothing lands during the test
        let core = makeCore(system)
        _ = ask(core, "dark")
        core.setKiwiVision(true)
        // Light found, dark asked: opposite of light is dark, already
        // asked — a stale read must not flip it or record dark found.
        _ = ask(core, "opposite")
        #expect(system.asked == [true])
        #expect(system.debt?.found.dark == false)
        _ = ask(core, "light")
        #expect(system.asked == [true, false])
        system.land()
        core.setKiwiVision(false)
        #expect(system.debt == nil)
        #expect(system.state.dark == false)
    }

    @Test("a fast on and off keeps the debt until the way back lands")
    func inFlightSwitchIsNotTheUsers() {
        let system = FakeSystem()
        system.lands = false
        let core = makeCore(system)
        _ = ask(core, "dark")
        core.setKiwiVision(true)
        core.setKiwiVision(false)
        #expect(system.asked == [true, false], "the way back is asked")
        #expect(system.debt?.setDark == false, "and still owed")
        system.land()
        core.retargetVisionAppearance(nil)  // the next start
        #expect(system.debt == nil)
        #expect(system.asked == [true, false])
        #expect(system.state.dark == false)
    }

    @Test("a way back left queued at quit is paid however late")
    func queuedHomeDebtSurvivesTheBound() {
        var now = Self.start
        let system = FakeSystem()
        system.state.auto = true
        system.lands = false
        let core = makeCore(system) { now }
        _ = ask(core, "dark")
        core.setKiwiVision(true)
        system.land()  // the way there landed
        core.setKiwiVision(false)  // the way back stays queued: quit
        system.queued.removeAll()  // the process exited first
        #expect(system.debt?.setDark == false)
        now += VisionAppearanceDebt.settleBound * 6
        system.lands = true
        core.retargetVisionAppearance(nil)  // the next start
        #expect(system.state.dark == false)
        #expect(system.debt == nil)
        #expect(system.rearms == 1, "Auto comes back after the switch")
        #expect(system.state.auto)
    }

    @Test("a way back that landed late still brings Auto back")
    func landedHomeRearmsAuto() {
        let system = FakeSystem()
        system.state.auto = true
        system.lands = false
        let core = makeCore(system)
        _ = ask(core, "dark")
        core.setKiwiVision(true)
        system.land()
        core.setKiwiVision(false)  // the way back stays queued
        system.land()  // and lands after the call: Auto now off
        core.retargetVisionAppearance(nil)  // the next start
        #expect(system.debt == nil)
        #expect(system.asked == [true, false])
        #expect(system.state == .init(dark: false, auto: true))
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

    @Test("a crash's debt is paid, and a new switch keeps its found")
    func leftoverDebtIsPaid() {
        let system = FakeSystem()
        system.state.dark = true
        system.debt = VisionAppearanceDebt(
            found: .init(dark: false, auto: false),
            setDark: true,
            askedAt: Self.start
        )
        let core = makeCore(system)
        _ = ask(core, "dark")
        core.setKiwiVision(true)  // e.g. init.lua, ahead of the pay
        #expect(system.asked.isEmpty)
        #expect(system.debt?.found.dark == false, "the crash's found")
        core.retargetVisionAppearance(nil)
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
