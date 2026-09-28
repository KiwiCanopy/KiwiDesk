import AppKit
import os

/// What `ScrollGestures` holds of the machine tap — the seam a
/// test replaces (#565).
protocol ScrollTapHandle: AnyObject {
    /// The chords whose scrolls the tap consumes; read per event
    /// on the tap thread.
    func setChords(_ chords: Set<ScrollChord>)
    func stop()
}

/// The one active scroll-wheel event tap (#1656, #1519).
///
/// An ACTIVE tap, because a gesture must swallow the scroll or
/// the window under the pointer scrolls too; it needs the
/// Accessibility grant alone — no Input Monitoring — which the
/// device build verified (input-and-animation.md). It runs on its
/// own thread: every scroll on the Mac waits on the callback, and
/// the main actor can block on a slow app's AX reply for seconds.
/// The decision is `ScrollGestureRouter`'s; consumers hear it on
/// the main queue, in order.
final class ScrollGestureTap: ScrollTapHandle, @unchecked Sendable {
    typealias Deliver = @Sendable ([ScrollGestureEvent]) -> Void

    private let chords = OSAllocatedUnfairLock<Set<ScrollChord>>(
        initialState: []
    )
    private let deliver: Deliver
    // Tap-thread state below; `installed` is written before the
    // start semaphore signals and read after it waits.
    private var router = ScrollGestureRouter()
    private var port: CFMachPort?
    private var timer: ScrollExpiryTimer?
    private var runLoop: CFRunLoop?
    private var installed = false

    private init(deliver: @escaping Deliver) {
        self.deliver = deliver
    }

    /// Builds and starts the tap; nil when macOS refuses it,
    /// which is what a missing Accessibility grant looks like.
    static func live(deliver: @escaping Deliver) -> ScrollTapHandle? {
        let tap = ScrollGestureTap(deliver: deliver)
        return tap.start() ? tap : nil
    }

    func setChords(_ chords: Set<ScrollChord>) {
        self.chords.withLock { $0 = chords }
    }

    func stop() {
        guard let runLoop else { return }
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
            [self] in
            if let port { CFMachPortInvalidate(port) }
            timer?.invalidate()
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
        thread.name = "KiwiDesk scroll tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        return installed
    }

    /// The scroll wheel alone: a wider mask is where an Input
    /// Monitoring prompt would come from (`ScrollSampleTests`).
    static let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue

    /// On the tap thread: creates the tap and its expiry timer.
    private func install() -> Bool {
        guard
            let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: Self.mask,
                callback: { _, type, event, info in
                    guard let info else {
                        return Unmanaged.passUnretained(event)
                    }
                    let tap = Unmanaged<ScrollGestureTap>
                        .fromOpaque(info).takeUnretainedValue()
                    return tap.handle(type, event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else { return false }
        self.port = port
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        timer = ScrollExpiryTimer(on: CFRunLoopGetCurrent()) {
            [self] in
            send(router.expire(now: CFAbsoluteTimeGetCurrent()))
            timer?.arm(at: router.deadline)
        }
        return true
    }

    /// The callback body, on the tap thread.
    private func handle(
        _ type: CGEventType,
        _ event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        guard type == .scrollWheel else {
            // macOS disables a tap it judged slow or that the
            // user's input overrode; a disabled tap passes every
            // scroll, so turn it back on.
            if type == .tapDisabledByTimeout
                || type == .tapDisabledByUserInput,
                let port
            {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        // A raw `Thread` drains no pool of its own until it exits.
        let consume = autoreleasepool {
            router.chords = chords.withLock { $0 }
            let routed = router.route(
                Self.sample(of: event),
                now: CFAbsoluteTimeGetCurrent()
            )
            send(routed.events)
            timer?.arm(at: router.deadline)
            return routed.consume
        }
        return consume ? nil : Unmanaged.passUnretained(event)
    }

    private func send(_ events: [ScrollGestureEvent]) {
        if !events.isEmpty { deliver(events) }
    }

    static func sample(of event: CGEvent) -> ScrollSample {
        ScrollSample(
            flags: event.flags,
            pointDeltaX: event.getDoubleValueField(
                .scrollWheelEventPointDeltaAxis2
            ),
            pointDeltaY: event.getDoubleValueField(
                .scrollWheelEventPointDeltaAxis1
            ),
            invertedBySystem: NSEvent(cgEvent: event)?
                .isDirectionInvertedFromDevice ?? false,
            scrollPhase: event.getIntegerValueField(
                .scrollWheelEventScrollPhase
            ),
            momentumPhase: event.getIntegerValueField(
                .scrollWheelEventMomentumPhase
            ),
            location: event.location
        )
    }
}
