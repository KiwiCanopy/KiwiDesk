import AppKit
import os

/// One chord the side tap answers: a key and the modifiers it is
/// pressed with, sides included, and the binding it fires (#2601).
struct SideTapRow: Hashable, Sendable {
    var keyCode: UInt32
    var modifiers: HotkeyModifiers
    var id: UInt32

    /// The row a press of `keyCode` holding `held` fires: among
    /// the rows it answers, the one naming the most sides, so a
    /// sided chord wins on its side and an either-side one on the
    /// other.
    static func match(
        _ rows: [SideTapRow],
        keyCode: UInt32,
        held: HotkeyModifiers
    ) -> SideTapRow? {
        rows.filter {
            $0.keyCode == keyCode && $0.modifiers.answers(held)
        }
        .max { lhs, rhs in
            let left = lhs.modifiers.intersection(.sides).rawValue
            let right = rhs.modifiers.intersection(.sides).rawValue
            // A tie breaks on the bits, never the rows' order.
            return (left.nonzeroBitCount, left)
                < (right.nonzeroBitCount, right)
        }
    }
}

/// What the keybinding manager holds of the keyboard tap — the
/// seam a test replaces (#565).
protocol SideTapHandle: AnyObject {
    /// The rows the tap answers; read per key press on its thread.
    func setRows(_ rows: [SideTapRow])
    func stop()
}

/// The one keyboard event tap (#2601), run only while modifier
/// sides are on and a sided shortcut exists.
///
/// ACTIVE, so a matching press is swallowed rather than typed;
/// macOS allows it with Accessibility alone (measured on macOS 27,
/// `docs/design-decisions.md`). It runs on its own thread, since
/// every key press on the Mac waits on the callback, and it
/// passes every press no row answers. A disabled tap — macOS
/// judged it slow — turns itself back on and says so.
final class ModifierSideTap: SideTapHandle, @unchecked Sendable {
    typealias Fire = @Sendable (UInt32) -> Void
    typealias Report = @Sendable (String) -> Void

    private let rows = OSAllocatedUnfairLock<[SideTapRow]>(
        initialState: []
    )
    private let fire: Fire
    private let report: Report
    // Tap-thread state; `installed` is written before the start
    // semaphore signals and read after it waits.
    private var port: CFMachPort?
    private var runLoop: CFRunLoop?
    private var installed = false

    private init(fire: @escaping Fire, report: @escaping Report) {
        self.fire = fire
        self.report = report
    }

    /// Builds and starts the tap; nil when macOS refuses it, which
    /// is what a missing Accessibility grant looks like.
    static func live(
        fire: @escaping Fire,
        report: @escaping Report
    ) -> SideTapHandle? {
        let tap = ModifierSideTap(fire: fire, report: report)
        return tap.start() ? tap : nil
    }

    func setRows(_ rows: [SideTapRow]) {
        self.rows.withLock { $0 = rows }
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
        thread.name = "KiwiDesk modifier side tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        return installed
    }

    /// Key-down alone: the press is all a shortcut fires on.
    static let mask = CGEventMask(1) << CGEventType.keyDown.rawValue

    /// On the tap thread: creates the tap.
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
                    let tap = Unmanaged<ModifierSideTap>
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

    /// The callback body, on the tap thread. A repeat of a
    /// matching press is swallowed and fires nothing, as Carbon's
    /// hotkeys never repeat.
    private func handle(
        _ type: CGEventType,
        _ event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            if type == .tapDisabledByTimeout
                || type == .tapDisabledByUserInput,
                let port
            {
                CGEvent.tapEnable(tap: port, enable: true)
                report("modifier side tap: re-enabled after \(type)")
            }
            return Unmanaged.passUnretained(event)
        }
        let code = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let held = HotkeyModifiers.held(by: event.flags)
        guard
            let row = SideTapRow.match(
                rows.withLock { $0 },
                keyCode: code,
                held: held
            )
        else { return Unmanaged.passUnretained(event) }
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            fire(row.id)
        }
        return nil
    }
}
