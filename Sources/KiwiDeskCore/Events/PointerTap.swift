import AppKit
import os

/// What `PointerConsumers` holds of the machine tap — the seam a
/// test replaces (#565).
protocol PointerTapHandle: AnyObject {
    /// The consumers' settings, read per event on the tap thread.
    func setSnapshot(_ snapshot: PointerTapSnapshot)
    func stop()
}

/// What the tap hands the main queue, in order.
struct PointerTapDelivery: Sendable {
    var grab: [ModifierGrabEvent]
    /// The bound buttons' presses and releases (#3281).
    var buttons: [PointerButtonEvent] = []
    /// The recognized pinches and rotations (#1873).
    var gestures: [TrackpadGestureEvent] = []
    /// macOS disabled the tap and it was turned back on, which
    /// ended any stream a consumer owned.
    var reenabled: Bool
}

/// The one active pointer tap (#2447, #2764 ruling 2026-11-01):
/// every consumer that must swallow a mouse-button or pointer
/// event joins it as a `PointerConsumers.Consumer`, and the tap
/// is created with the union of the live consumers' masks.
///
/// ACTIVE, at `.cgSessionEventTap`, because a grab must swallow
/// the press or the app under the pointer clicks too; it asks for
/// the Accessibility-class `PostEvent` service alone
/// (input-and-animation.md). It runs on its own thread: every
/// pointer event on the Mac waits on the callback, which does no
/// AX, no window lookup and no main-actor hop. The decision is
/// `PointerTapRouter`'s; consumers hear it on the main queue.
final class PointerTap: PointerTapHandle, @unchecked Sendable {
    typealias Deliver = @Sendable (PointerTapDelivery) -> Void

    private let snapshot = OSAllocatedUnfairLock(
        initialState: PointerTapSnapshot.off
    )
    private let deliver: Deliver
    private let mask: CGEventMask
    // Tap-thread state below; `installed` is written before the
    // start semaphore signals and read after it waits.
    private var router = PointerTapRouter()
    private var port: CFMachPort?
    private var runLoop: CFRunLoop?
    private var installed = false

    private init(mask: CGEventMask, deliver: @escaping Deliver) {
        self.mask = mask
        self.deliver = deliver
    }

    /// Builds and starts the tap over `mask`; nil when macOS
    /// refuses it, which is what a missing Accessibility grant
    /// looks like.
    static func live(
        mask: CGEventMask,
        deliver: @escaping Deliver
    ) -> PointerTapHandle? {
        let tap = PointerTap(mask: mask, deliver: deliver)
        return tap.start() ? tap : nil
    }

    func setSnapshot(_ snapshot: PointerTapSnapshot) {
        self.snapshot.withLock { $0 = snapshot }
    }

    func stop() {
        guard let runLoop else { return }
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
            [self] in
            if let port { CFMachPortInvalidate(port) }
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
        CFRunLoopWakeUp(runLoop)
        self.runLoop = nil
    }

    private func start() -> Bool {
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in
            installed = install()
            if installed { runLoop = CFRunLoopGetCurrent() }
            ready.signal()
            if installed { CFRunLoopRun() }
        }
        thread.name = "KiwiDesk pointer tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        return installed
    }

    /// On the tap thread: creates the tap over the union mask.
    private func install() -> Bool {
        guard
            let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, info in
                    guard let info else {
                        return Unmanaged.passUnretained(event)
                    }
                    let tap = Unmanaged<PointerTap>
                        .fromOpaque(info).takeUnretainedValue()
                    return tap.handle(type, event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else { return false }
        self.port = port
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        return true
    }

    /// The callback body, on the tap thread.
    private func handle(
        _ type: CGEventType,
        _ event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        let now = CFAbsoluteTimeGetCurrent()
        guard let kind = Self.kind(of: type, event) else {
            // The one re-enable path: a disabled tap passes every
            // event, so turn it back on and end what it owned.
            if type == .tapDisabledByTimeout
                || type == .tapDisabledByUserInput,
                let port
            {
                CGEvent.tapEnable(tap: port, enable: true)
                let routed = router.reseed(now: now)
                deliver(
                    .init(
                        grab: routed.grab,
                        buttons: routed.buttons,
                        reenabled: true
                    )
                )
            }
            return Unmanaged.passUnretained(event)
        }
        // A raw `Thread` drains no pool of its own until it exits.
        let swallow = autoreleasepool {
            router.snapshot = snapshot.withLock { $0 }
            let routed = router.route(
                PointerSample(
                    kind: kind,
                    location: event.location,
                    chord: ScrollChord(flags: event.flags)
                ),
                now: now
            )
            if !routed.grab.isEmpty || !routed.buttons.isEmpty
                || !routed.gestures.isEmpty
            {
                deliver(
                    .init(
                        grab: routed.grab,
                        buttons: routed.buttons,
                        gestures: routed.gestures,
                        reenabled: false
                    )
                )
            }
            return routed.swallow
        }
        return swallow ? nil : Unmanaged.passUnretained(event)
    }

    static func kind(
        of type: CGEventType,
        _ event: CGEvent
    ) -> PointerSample.Kind? {
        if type.rawValue == PointerConsumers.gestureEventType
            || type.rawValue == PointerConsumers.dockEventType
        {
            return .gesture(
                gesture(
                    event,
                    dock: type.rawValue == PointerConsumers.dockEventType
                )
            )
        }
        let other = PointerButton.other(
            Int(event.getIntegerValueField(.mouseEventButtonNumber))
        )
        switch type {
        case .leftMouseDown: return .leftDown
        case .leftMouseDragged: return .leftDragged
        case .leftMouseUp: return .leftUp
        case .mouseMoved: return .mouseMoved
        case .flagsChanged: return .flagsChanged
        case .rightMouseDown: return .buttonDown(.right)
        case .rightMouseDragged: return .buttonDragged(.right)
        case .rightMouseUp: return .buttonUp(.right)
        case .otherMouseDown: return .buttonDown(other)
        case .otherMouseDragged: return .buttonDragged(other)
        case .otherMouseUp: return .buttonUp(other)
        default: return nil
        }
    }

    /// A gesture event's private fields (#1873,
    /// `GestureEventSample`).
    static func gesture(
        _ event: CGEvent,
        dock: Bool
    ) -> GestureEventSample {
        func field(_ raw: UInt32) -> CGEventField {
            unsafeBitCast(raw, to: CGEventField.self)
        }
        return GestureEventSample(
            subtype: Int(event.getIntegerValueField(field(110))),
            phase: Int(event.getIntegerValueField(field(132))),
            value: event.getDoubleValueField(field(dock ? 124 : 113)),
            dock: dock,
            axis: dock ? Int(event.getIntegerValueField(field(123))) : 0,
            fingers: dock ? TouchFingerCount.now : 0
        )
    }
}
