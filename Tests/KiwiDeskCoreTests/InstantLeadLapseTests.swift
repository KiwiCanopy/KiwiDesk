import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An instant write's commanded ring lead that lapses with no echo
/// owes one steady overlay sync at the lapse (#2882): an app that
/// refused the write sends no echo and no WindowServer event, so
/// nothing else re-syncs and the ring stayed at the ask. The
/// applier's clock and its lapse scheduler are injected, so the
/// grace passes by hand.
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
        core.tiler.applier.instantLeadLapsed = { id in
            hands.lapses += 1
            wired(id)
        }
        core.updateBorders()
        core.tiler.setFrame(id, asked)
        core.updateBorders()
        return (core, hands)
    }

    private func passGrace(_ hands: Hands) {
        hands.now += 1.1
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

    /// A newer write owns the lead: the older check stands down
    /// and the newer one lapses once.
    @Test("a newer write's lead lapses once, the older stands down")
    func newerWriteOwnsTheLead() {
        let (core, hands) = written()
        hands.now += 0.5
        core.tiler.setFrame(id, asked.offsetBy(dx: 20, dy: 0))
        passGrace(hands)
        #expect(hands.lapses == 1)
    }

    /// Inside the grace nothing lapses.
    @Test("inside the grace the lead stands")
    func insideTheGrace() throws {
        let (core, hands) = written()
        hands.now += 0.5
        hands.owed.forEach { $0() }
        #expect(hands.lapses == 0)
        #expect(core.borders.lastFrame(id) == asked)
    }
}
