import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An instant write's commanded ring lead that lapses with no echo
/// owes one steady overlay sync at the lapse (#2882): an app that
/// refused the write sends no echo and no WindowServer event, so
/// nothing else re-syncs and the ring stayed at the ask. The
/// applier's clock and its lapse scheduler are injected, so the
/// grace passes by hand, and one sweep serves every lead owed.
@Suite("An instant lead's lapse re-syncs the ring (#2882)", .serialized)
@MainActor
struct InstantLeadLapseTests {
    private let id = WindowID(1)
    private let real = CGRect(x: 100, y: 100, width: 600, height: 400)
    private let asked = CGRect(x: 300, y: 100, width: 600, height: 400)

    /// The applier's clock and the lapse checks it scheduled.
    private final class Hands: @unchecked Sendable {
        var now: TimeInterval = 100
        var owed: [@MainActor () -> Void] = []
        var lapses = 0
    }

    /// One focused window at `real`, its ring drawn, then an
    /// instant write of `asked` the window has not answered.
    private func written() -> (KiwiCore, Hands) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        var window = ManagedWindow(id: id, pid: 100, appName: "App")
        window.frame = real
        core.state.windows.upsert(window)
        core.state.workspaces.add(id, to: "1")
        core.state.workspaces.focus(id, in: "1")
        let hands = Hands()
        core.tiler.applier.clock = { hands.now }
        core.tiler.applier.scheduleLapse = { _, work in
            hands.owed.append(work)
        }
        let wired = core.tiler.applier.instantLeadLapsed
        core.tiler.applier.instantLeadLapsed = {
            hands.lapses += 1
            wired()
        }
        core.updateBorders()
        core.tiler.setFrame(id, asked)
        core.updateBorders()
        return (core, hands)
    }

    private func passGrace(_ hands: Hands) {
        hands.now += 1.1
        fire(hands)
    }

    /// Runs the sweeps scheduled so far.
    private func fire(_ hands: Hands) {
        let owed = hands.owed
        hands.owed = []
        owed.forEach { $0() }
    }

    @Test("an unanswered lead lapses into the state frame")
    func lapseRendersTheState() throws {
        let (core, hands) = written()
        try #require(core.borders.lastFrame(id) == asked)
        passGrace(hands)
        #expect(hands.lapses == 1)
        #expect(core.borders.lastFrame(id) == real)
    }

    /// The control: an echo answered first, so no lapse is owed.
    @Test("an echo before the grace owes no lapse")
    func echoAnswersFirst() {
        let (core, hands) = written()
        core.tiler.clearInstantTarget(id)
        passGrace(hands)
        #expect(hands.lapses == 0)
    }

    /// A newer write owns the lead: the first sweep finds it still
    /// inside its grace and the next one lapses it, once.
    @Test("a newer write's lead lapses once, at its own grace")
    func newerWriteOwnsTheLead() {
        let (core, hands) = written()
        hands.now += 0.5
        core.tiler.setFrame(id, asked.offsetBy(dx: 20, dy: 0))
        hands.now += 0.6
        fire(hands)
        #expect(hands.lapses == 0)
        passGrace(hands)
        #expect(hands.lapses == 1)
        passGrace(hands)
        #expect(hands.lapses == 1)
    }

    /// Several leads lapsing together cost one sync, not one each.
    @Test("leads lapsing together re-sync once")
    func batchSyncsOnce() {
        let (core, hands) = written()
        core.tiler.setFrame(WindowID(2), asked)
        core.tiler.setFrame(WindowID(3), asked)
        passGrace(hands)
        #expect(hands.lapses == 1)
    }

    /// A reader's expiry of the lead between the grace and the
    /// sweep cannot swallow the lapse.
    @Test("an expiring read before the sweep keeps the lapse")
    func readBeforeTheSweep() {
        let (core, hands) = written()
        hands.now += 1.02
        #expect(core.tiler.recentInstantTarget(id) == nil)
        fire(hands)
        #expect(hands.lapses == 1)
        #expect(core.borders.lastFrame(id) == real)
    }

    /// Inside the grace nothing lapses.
    @Test("inside the grace the lead stands")
    func insideTheGrace() throws {
        let (core, hands) = written()
        hands.now += 0.5
        fire(hands)
        #expect(hands.lapses == 0)
        #expect(core.borders.lastFrame(id) == asked)
    }
}
