import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pointer rest, hover focus's trigger (#1869): only user
/// motion arms it, jitter around the last rest does not, and the
/// monitor exists only while the setting is on and the tracker
/// runs. The dwell itself is a sleep; these drive the rest
/// directly rather than waiting it out.
@Suite("Pointer rest (#1869)")
@MainActor
struct PointerRestTests {
    /// A rest with a counting fake monitor.
    private func makeRest() -> (PointerRest, Counter) {
        let rest = PointerRest()
        let counter = Counter()
        rest.makeMonitor = { _ in
            counter.installs += 1
            return NSObject()
        }
        rest.removeMonitor = { _ in counter.removals += 1 }
        return (rest, counter)
    }

    @MainActor
    final class Counter {
        var installs = 0
        var removals = 0
    }

    @Test("The monitor runs only while enabled AND started")
    func monitorFollowsBoth() {
        let (rest, counter) = makeRest()
        rest.setEnabled(true)
        #expect(!rest.isListening, "not started yet")
        rest.start()
        #expect(rest.isListening)
        #expect(counter.installs == 1)
        rest.setEnabled(true)
        #expect(counter.installs == 1, "no second monitor")
        rest.setEnabled(false)
        #expect(!rest.isListening)
        #expect(counter.removals == 1)
        rest.setEnabled(true)
        rest.stop()
        #expect(!rest.isListening)
        #expect(counter.removals == 2)
    }

    @Test("A move arms the dwell; the rest reports where it is")
    func moveArmsAndRestReports() {
        let (rest, _) = makeRest()
        var rests: [CGPoint] = []
        rest.onRest = { point, _ in rests.append(point) }
        rest.location = { CGPoint(x: 101, y: 50) }
        #expect(!rest.isArmed)
        rest.moved(to: CGPoint(x: 100, y: 50))
        #expect(rest.isArmed)
        rest.rest()
        #expect(!rest.isArmed)
        #expect(rests == [CGPoint(x: 101, y: 50)])
    }

    @Test("Jitter around the last rest does not re-arm")
    func jitterIsNoTravel() {
        let (rest, _) = makeRest()
        rest.location = { CGPoint(x: 100, y: 50) }
        rest.moved(to: CGPoint(x: 100, y: 50))
        rest.rest()
        rest.moved(to: CGPoint(x: 103, y: 52))
        #expect(!rest.isArmed, "within the still radius")
        rest.moved(to: CGPoint(x: 120, y: 50))
        #expect(rest.isArmed, "past it")
    }

    @Test("Turning it off drops an armed dwell")
    func offDisarms() {
        let (rest, _) = makeRest()
        rest.setEnabled(true)
        rest.start()
        rest.moved(to: CGPoint(x: 1, y: 1))
        #expect(rest.isArmed)
        rest.setEnabled(false)
        #expect(!rest.isArmed)
    }

    @Test("A mouse settings write tells the engine's listener")
    func settingsWriteIsHeard() {
        let directory =
            testTemporaryDirectory
            .appendingPathComponent("kiwidesk-rest-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: directory)
        var heard: [Bool] = []
        core.tiler.onMouseSettings = { heard.append($0.hoverFocus) }
        core.tiler.settings.mouse.hoverFocus = true
        core.tiler.settings.animations.durationMS = 123
        core.tiler.settings.mouse.hoverFocus = false
        #expect(heard == [true, false], "an unrelated write is silent")
    }
}

extension PointerRestTests {
    @Test("A pointer that kept moving where it went unheard re-arms")
    func unheardMotionReArms() {
        let rest = PointerRest()
        var rests = 0
        rest.onRest = { _, _ in rests += 1 }
        rest.moved(to: CGPoint(x: 10, y: 10))
        rest.location = { CGPoint(x: 60, y: 10) }
        rest.rest()
        #expect(rests == 0)
        #expect(rest.isArmed)
        rest.rest()
        #expect(rests == 1, "still where the re-arm heard it")
    }

    @Test("The rest hands back the focus read when it armed")
    func restCarriesTheArmedFocus() {
        let rest = PointerRest()
        var focus: WindowID? = WindowID(1)
        rest.noteArm = { focus }
        var armed: [WindowID?] = []
        rest.onRest = { _, id in armed.append(id) }
        rest.location = { CGPoint(x: 10, y: 10) }
        rest.moved(to: CGPoint(x: 10, y: 10))
        focus = WindowID(2)
        rest.rest()
        #expect(armed == [WindowID(1)])
    }
}

extension PointerRestTests {
    /// A warp moves the pointer with no event; the re-arm that
    /// follows must not adopt the focus the warp's shortcut set.
    @Test("A re-arm keeps the focus the user's own move armed with")
    func reArmKeepsTheArmedFocus() {
        let rest = PointerRest()
        var focus: WindowID? = WindowID(1)
        rest.noteArm = { focus }
        var armed: [WindowID?] = []
        rest.onRest = { _, id in armed.append(id) }
        rest.moved(to: CGPoint(x: 10, y: 10))
        focus = WindowID(2)
        rest.location = { CGPoint(x: 400, y: 10) }
        rest.rest()
        #expect(armed.isEmpty, "re-armed, not fired")
        rest.rest()
        #expect(armed == [WindowID(1)])
    }
}
