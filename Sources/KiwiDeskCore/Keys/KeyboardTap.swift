import AppKit
import os

/// A system-wide reader of key events joining the one keyboard tap
/// (input-and-animation.md), each with its own mask. Declared in
/// precedence order: the tap asks each live consumer in turn, a
/// swallowing one first, and a listen-only one hears every event
/// in its mask, swallowed or not.
enum KeyboardTapConsumer: CaseIterable, Hashable, Sendable {
    /// Key sequences (#1871): key-down, swallowing a leader and every
    /// key while one is open, which outranks a sided chord; a
    /// mouse-down closes an open one.
    case sequences
    /// Sided chords (#2601): key-down, swallowing a match.
    case sides
    /// Modifier taps (#1872): modifier changes, key-down and
    /// mouse-down, so a key or ⌘-click ends a count; swallows
    /// nothing.
    case modifierTaps

    var mask: CGEventMask {
        switch self {
        case .sequences: Self.sequencesMask
        case .sides: Self.sidesMask
        case .modifierTaps: Self.modifierTapsMask
        }
    }

    var swallows: Bool { self != .modifierTaps }

    static let sequencesMask =
        bit(.keyDown) | bit(.leftMouseDown) | bit(.rightMouseDown)
        | bit(.otherMouseDown)
    static let sidesMask = bit(.keyDown)
    static let modifierTapsMask =
        bit(.flagsChanged) | bit(.keyDown) | bit(.leftMouseDown)
        | bit(.rightMouseDown) | bit(.otherMouseDown)

    /// The tap's option for `consumers`: active only while one
    /// swallows, listen-only otherwise.
    static func options(_ consumers: Set<Self>) -> CGEventTapOptions {
        consumers.contains { $0.swallows } ? .defaultTap : .listenOnly
    }

    /// The mask a tap serving `consumers` is created with.
    static func union(_ consumers: Set<Self>) -> CGEventMask {
        consumers.reduce(0) { $0 | $1.mask }
    }

    private static func bit(_ type: CGEventType) -> CGEventMask {
        CGEventMask(1) << type.rawValue
    }
}

/// What the keybinding manager holds of the keyboard tap — the
/// seam a test replaces (#565).
protocol KeyboardTapHandle: AnyObject {
    /// The consumers it was built for; a change rebuilds it.
    var consumers: Set<KeyboardTapConsumer> { get }
    /// The rows each consumer answers; read on its thread. New rows
    /// close an open key sequence.
    func setRows(_ rows: KeyboardTapRows)
    func stop()
    /// The sequence decisions made since the last drain, in order
    /// (#1871): `fire(sequenceFireID)` asks the main actor to take
    /// them.
    func drainSequenceDecisions() -> [KeySequenceDecision]
    /// Closes an open sequence at the tap's next event, its later
    /// decisions stamped `generation`.
    func requestSequenceClose(generation: UInt64)
    /// The taps held while an own floating panel is key (#1229);
    /// the detector keeps counting.
    func holdTaps(_ hold: ModifierTapHold)
}

/// The one keyboard event tap (#2601, #1872, #1871), run only
/// while a consumer has rows.
///
/// ACTIVE while a swallowing consumer is live — `.sequences` or
/// `.sides` — so a press one answers is swallowed rather than
/// typed, listen-only otherwise; macOS allows both with
/// Accessibility alone (measured on macOS 27,
/// `docs/design-decisions.md`). It runs on its own thread, since
/// every key press on the Mac waits on the callback, and passes
/// every event no swallowing consumer answers. A disabled tap —
/// macOS judged it slow — turns itself back on, forgets a
/// half-counted tap and an open sequence, and says so.
final class KeyboardTap: KeyboardTapHandle, @unchecked Sendable {
    typealias Fire = @Sendable (UInt32) -> Void
    typealias Report = @Sendable (String) -> Void

    let consumers: Set<KeyboardTapConsumer>
    private let sideRows = OSAllocatedUnfairLock<[SideTapRow]>(
        initialState: []
    )
    private let router = OSAllocatedUnfairLock(
        initialState: ModifierTapRouter()
    )
    /// The open-or-closed sequence state, decided on this thread
    /// (#1871), and the decisions waiting for the main actor.
    let sequenceState = OSAllocatedUnfairLock(
        initialState: SequenceTapState()
    )
    private let tapHold = OSAllocatedUnfairLock(
        initialState: ModifierTapHold.none
    )
    let fire: Fire
    private let report: Report
    // Tap-thread state; `installed` is written before the start
    // semaphore signals and read after it waits.
    private var port: CFMachPort?
    private var runLoop: CFRunLoop?
    private var installed = false

    private init(
        consumers: Set<KeyboardTapConsumer>,
        fire: @escaping Fire,
        report: @escaping Report
    ) {
        self.consumers = consumers
        self.fire = fire
        self.report = report
    }

    #if DEBUG
        /// Tests only: a tap that never installs, whose consumers a
        /// suite drives with fabricated events. Production must not
        /// read this.
        static func unstarted(
            consumers: Set<KeyboardTapConsumer>,
            fire: @escaping Fire
        ) -> KeyboardTap {
            KeyboardTap(consumers: consumers, fire: fire, report: { _ in })
        }
        /// Tests only: the callback's body, true where it swallowed
        /// the event. Production must not read this.
        func handledForTesting(_ type: CGEventType, _ event: CGEvent) -> Bool {
            handle(type, event) == nil
        }
    #endif

    /// Builds and starts the tap; nil when macOS refuses it, which
    /// is what a missing Accessibility grant looks like.
    static func live(
        consumers: Set<KeyboardTapConsumer>,
        fire: @escaping Fire,
        report: @escaping Report
    ) -> KeyboardTapHandle? {
        let tap = KeyboardTap(
            consumers: consumers,
            fire: fire,
            report: report
        )
        return tap.start() ? tap : nil
    }

    func holdTaps(_ hold: ModifierTapHold) {
        tapHold.withLock { $0 = hold }
    }

    func setRows(_ rows: KeyboardTapRows) {
        sideRows.withLock { $0 = rows.sides }
        router.withLock { $0.setRows(rows.taps) }
        sequenceState.withLock { $0.reset(rows) }
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
        thread.name = "KiwiDesk keyboard tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        return installed
    }

    /// On the tap thread: creates the tap from the consumers' union.
    private func install() -> Bool {
        guard
            let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: KeyboardTapConsumer.options(consumers),
                eventsOfInterest: KeyboardTapConsumer.union(consumers),
                callback: { _, type, event, info in
                    guard let info else {
                        return Unmanaged.passUnretained(event)
                    }
                    let tap = Unmanaged<KeyboardTap>
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

    /// The callback body, on the tap thread: every live consumer
    /// in precedence order, the event swallowed once any did.
    private func handle(
        _ type: CGEventType,
        _ event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            // A count half-heard across the gap is no tap.
            route(.key)
            // Keys passed while it was off: an open sequence lost them.
            closeSequenceAfterGap()
            report("keyboard tap: re-enabled after \(type)")
            return pass
        }
        var swallowed = false
        for consumer in KeyboardTapConsumer.allCases
        where consumers.contains(consumer) {
            switch consumer {
            case .sequences:
                if sequenceEvent(type, event) { swallowed = true }
            case .sides:
                if !swallowed, type == .keyDown, sideKey(event) {
                    swallowed = true
                }
            case .modifierTaps:
                if let input = Self.tapInput(type, event) { route(input) }
            }
        }
        return swallowed ? nil : pass
    }

    /// What `.modifierTaps` hears of an event, nil for nothing.
    private static func tapInput(
        _ type: CGEventType,
        _ event: CGEvent
    ) -> ModifierTapDetector.Input? {
        switch type {
        case .keyDown: return .key
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return .mouseDown
        case .flagsChanged:
            // The tap's own uptime clock: `CGEvent.timestamp`'s
            // unit differs by architecture (mach ticks on arm64).
            let time =
                TimeInterval(
                    clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
                ) / 1e9
            return .flags(HotkeyModifiers.held(by: event.flags), at: time)
        default: return nil
        }
    }

    /// `.sides`: whether a row answers the press, which is then
    /// swallowed. A repeat is swallowed and fires nothing, as
    /// Carbon's hotkeys never repeat.
    private func sideKey(_ event: CGEvent) -> Bool {
        let code = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let held = HotkeyModifiers.held(by: event.flags)
        guard
            let row = SideTapRow.match(
                sideRows.withLock { $0 },
                keyCode: code,
                held: held
            )
        else { return false }
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            fire(row.id)
        }
        return true
    }

    /// `.modifierTaps`: feeds the detector, fires what the hold
    /// lets through, and arms the gap timer a single tap waits on,
    /// which fires only if the hold lets it at the tap and at the
    /// lapse.
    private func route(_ input: ModifierTapDetector.Input) {
        let (ids, pending) = router.withLock { $0.feed(input) }
        let atTap = tapHold.withLock { $0 }
        ids.filter { lets(id: $0, atTap) }.forEach(fireOrOpen)
        if let pending {
            DispatchQueue.global(qos: .userInteractive).asyncAfter(
                deadline: .now() + ModifierTapDetector.gapLimit
            ) { [weak self] in
                guard let self,
                    let id = self.router.withLock({ $0.expire(pending) }),
                    self.lets(id: id, atTap),
                    self.lets(id: id, self.tapHold.withLock { $0 })
                else { return }
                self.fireOrOpen(id)
            }
        }
    }

    /// Whether `hold` lets the row fired as `id` through.
    private func lets(id: UInt32, _ hold: ModifierTapHold) -> Bool {
        guard hold != .none else { return true }
        let row = router.withLock { $0.rows.first { $0.id == id } }
        return row.map(hold.lets) ?? false
    }
}
