import CoreGraphics
import Testing

@testable import KiwiDeskCore

private final class ScrollStub: ScrollTapHandle {
    func setChords(_ chords: ScrollTapChords) {}
    func stop() {}
}

private final class PointerStub: PointerTapHandle {
    func setSnapshot(_ snapshot: PointerTapSnapshot) {}
    func stop() {}
}

private final class ReaderStub: TouchReaderHandle {
    var travel: TouchTravel.Reading?
    func stop() {}
}

/// Each front hands its factory the hold it was given (#3407 ▸
/// Amendment), so a tap built at a start reads the keybinding
/// manager's hold rather than a box nobody holds.
/// `HyperHoldSeamTests` holds the live factories' forwarding.
@MainActor
@Suite("Hyper hold reaches the tap factories")
struct HyperHoldFactoryTests {
    @Test("the scroll front builds its tap with its hold")
    func scrollFront() {
        let front = ScrollGestures()
        front.onLog = { _ in }
        let hold = HyperHold()
        front.hyperHold = hold
        var handed: HyperHold?
        front.makeTap = { given, _ in
            handed = given
            return ScrollStub()
        }
        front.setHandler { _, _ in }
        front.configure(
            ScrollGestureSettings(
                routes: [.hyper: ScrollRoute(wheel: .family(.walk))],
                naturalTrackpad: true,
                naturalMouse: true
            )
        )
        front.start()
        #expect(handed === hold)
    }

    @Test("the pointer front builds its tap with its hold")
    func pointerFront() {
        let front = PointerConsumers()
        front.onLog = { _ in }
        let hold = HyperHold()
        front.hyperHold = hold
        var handed: HyperHold?
        front.makeTap = { _, given, _ in
            handed = given
            return PointerStub()
        }
        front.setGrabHandler { _ in }
        front.start()
        #expect(handed === hold)
    }

    @Test("the touch front builds its reader with its hold")
    func touchFront() {
        let front = TouchGestures()
        front.onLog = { _ in }
        front.readSystemGestures = { .unread }
        let hold = HyperHold()
        front.hyperHold = hold
        var handed: HyperHold?
        front.makeReader = { given, _ in
            handed = given
            return ReaderStub()
        }
        front.setHandler { _, _, _ in }
        front.resolve(
            [GestureKey(.tap3, .hyper): .run(LuaAction(lua: "x()"))],
            natural: true
        )
        front.start()
        #expect(handed === hold)
    }
}
