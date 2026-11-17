import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A registrar that keeps what is registered and reports releases
/// as Carbon does.
@MainActor
private final class LiveRegistrar: HotkeyRegistrar,
    HotkeyReleaseReporting
{
    var onRelease: @MainActor (UInt32) -> Void = { _ in }
    var live: [UInt32: (code: UInt32, mask: UInt32, fire: () -> Void)] =
        [:]
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        defer { nextID += 1 }
        live[nextID] = (keyCode, modifiers.carbonMask, handler)
        return nextID
    }

    func unregister(id: UInt32) { live[id] = nil }

    func press(_ code: UInt32) {
        live.values.first { $0.code == code && $0.mask == 0 }?.fire()
    }

    func release(_ code: UInt32) {
        for (id, entry) in live where entry.code == code {
            onRelease(id)
        }
    }
}

/// The gesture taps read the Hyper layer's one hold (#3407 ▸
/// Amendment): Hyper is no event flag, so a tap whose chord build
/// skips the hold never sees it, and the watchdog ending a hold
/// mid-gesture hands the next event back to the app.
@MainActor
@Suite("Hyper hold reaches the gesture taps")
struct HyperHoldWiringTests {
    private let f18 = HyperSourceKey.triggerKeyCode

    private func scroll() throws -> CGEvent {
        try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: 3,
                wheel2: 0,
                wheel3: 0
            )
        )
    }

    private func rightDown() throws -> CGEvent {
        try #require(
            CGEvent(
                mouseEventSource: nil,
                mouseType: .rightMouseDown,
                mouseCursorPosition: CGPoint(x: 4, y: 5),
                mouseButton: .right
            )
        )
    }

    private func scrollTap(_ hold: HyperHold) -> ScrollGestureTap {
        let tap = ScrollGestureTap(hyper: hold) { _ in }
        tap.setChords(ScrollTapChords(wheel: [.hyper]))
        return tap
    }

    private func manager(
        _ registrar: LiveRegistrar
    ) -> KeybindingManager {
        let keys = KeybindingManager(registrar: registrar)
        keys.onLog = { _ in }
        keys.hyperEnabled = true
        return keys
    }

    @Test("the scroll tap takes a hyper wheel only while Hyper is held")
    func scrollTapReadsTheHold() throws {
        let hold = HyperHold()
        let tap = scrollTap(hold)
        #expect(tap.handle(.scrollWheel, try scroll()) != nil)
        hold.isHeld = true
        #expect(tap.handle(.scrollWheel, try scroll()) == nil)
    }

    @Test("the pointer tap takes a hyper click only while Hyper is held")
    func pointerTapReadsTheHold() throws {
        let hold = HyperHold()
        let tap = PointerTap(mask: 0, hyper: hold) { _ in }
        let key = GestureKey(.rightClick, .hyper)
        tap.setSnapshot(
            PointerTapSnapshot(
                grab: nil,
                buttons: PointerButtonSettings(
                    resolved: [key: .run(LuaAction(lua: "x()"))]
                )
            )
        )
        #expect(tap.handle(.rightMouseDown, try rightDown()) != nil)
        hold.isHeld = true
        #expect(tap.handle(.rightMouseDown, try rightDown()) == nil)
    }

    @Test("the core hands every reader the keybinding manager's hold")
    func coreWiresOneHold() {
        let core = makeTestCore()
        let hold = core.keys.hyperHold
        #expect(core.mouse.scroll.hyperHold === hold)
        #expect(core.mouse.pointer.hyperHold === hold)
        #expect(core.mouse.trackpad.hyperHold === hold)
    }

    @Test("a press and its release move the hold")
    func pressMovesTheHold() {
        let registrar = LiveRegistrar()
        let keys = manager(registrar)
        #expect(!keys.hyperHold.isHeld)
        registrar.press(f18)
        #expect(keys.hyperHold.isHeld)
        registrar.release(f18)
        #expect(!keys.hyperHold.isHeld)
    }

    @Test("the watchdog ending a hold mid-gesture frees the next event")
    func watchdogEndsTheGesture() throws {
        let registrar = LiveRegistrar()
        let keys = manager(registrar)
        var fire: (@MainActor () -> Void)?
        keys.hyperSchedule = { _, work in
            fire = work
            return {}
        }
        registrar.press(f18)
        let tap = scrollTap(keys.hyperHold)
        #expect(tap.handle(.scrollWheel, try scroll()) == nil)
        #expect(tap.handle(.scrollWheel, try scroll()) == nil)
        let work = try #require(fire)
        work()
        #expect(!keys.hyperHold.isHeld)
        // The release never came; the next notch is the app's.
        #expect(tap.handle(.scrollWheel, try scroll()) != nil)
    }

    @Test("a hyper gesture is work for a bare Hyper press")
    func gestureSilencesTheBareCue() {
        let registrar = LiveRegistrar()
        let keys = manager(registrar)
        var reports = 0
        keys.onBareHyper = { reports += 1 }
        keys.setHyperGestureBound(true)
        #expect(keys.hyperHasShortcuts)
        registrar.press(f18)
        #expect(reports == 0)
        registrar.release(f18)
        keys.setHyperGestureBound(false)
        #expect(!keys.hyperHasShortcuts)
        registrar.press(f18)
        #expect(reports == 1)
    }

    @Test("a resolved hyper gesture reaches the manager")
    func applyGesturesTellsTheManager() {
        let core = makeTestCore()
        #expect(!core.keys.hyperHasShortcuts)
        let bound = core.execute(
            "gesture.bind",
            args: [.string("wheel"), .string("hyper"), .string("walk")]
        )
        #expect(bound.isSuccess)
        #expect(core.keys.hyperHasShortcuts)
        _ = core.execute(
            "gesture.unbind",
            args: [.string("wheel"), .string("hyper")]
        )
        #expect(!core.keys.hyperHasShortcuts)
    }
}
