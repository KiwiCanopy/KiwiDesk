import AppKit
import KiwiDeskCore

/// The chord-capture engine behind `KeyRecorderField` (#68
/// recorder UX): lock-on-full-release. The pending combo is
/// snapshotted when keys go DOWN and commits only once every
/// key and modifier is released — so releases can trigger the
/// commit but never change the chord, and a staggered release
/// (⌘ let go a split second before J) still locks ⌘J.
///
/// Rules:
/// - A base keyDown snapshots the pending combo (key + the
///   modifiers held at that moment). Pressing another base
///   key AFTER releasing the first re-snapshots — you can
///   correct mid-chord (⌘J, J up, K down → ⌘K).
/// - A second base key pressed WHILE the first is still held
///   is a chord attempt: the pending combo keeps the first
///   key and the field shows a one-key hint instead of
///   silently switching (a shortcut is modifiers + one key).
/// - While a base key is held, added modifiers ACCUMULATE
///   into the pending combo; dropped ones are ignored — an
///   early modifier release can't strip the chord.
/// - Bare Escape cancels. Any mouse click cancels
///   (`.clickAway`, so the field can absorb the click on its
///   own button). App deactivation cancels too — a system
///   chord (⌘Tab, ⌘⇧4) steals its keyUps, which would
///   otherwise leave `heldKeys` stuck and the recorder
///   un-lockable.
///
/// The pure state machine lives in `handle(_:keyCode:flags:)`
/// so `ChordRecorderTests` can drive every sequence without
/// constructing `NSEvent`s; the monitors are a thin shell.
@MainActor
final class ChordRecorder {
    enum Outcome {
        /// Every key released — the chord locks in.
        case chord(String)
        /// Bare Escape, deactivation, or an unrepresentable
        /// key.
        case cancelled
        /// A mouse click ended the recording.
        case clickAway
    }

    enum EventKind {
        case keyDown
        case keyUp
        case flagsChanged
    }

    private struct Pending {
        var keyCode: UInt32
        var command: Bool
        var option: Bool
        var control: Bool
        var shift: Bool

        mutating func accumulate(
            _ flags: NSEvent.ModifierFlags
        ) {
            command = command || flags.contains(.command)
            option = option || flags.contains(.option)
            control = control || flags.contains(.control)
            shift = shift || flags.contains(.shift)
        }

        var combo: String? {
            KeyCombo.comboString(
                keyCode: keyCode,
                command: command,
                option: option,
                control: control,
                shift: shift
            )
        }
    }

    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var deactivation: (any NSObjectProtocol)?
    private var heldKeys: Set<UInt16> = []
    private var pending: Pending?
    private var onPreview: (String) -> Void = { _ in }
    private var onHint: (String?) -> Void = { _ in }
    private var onFinish: (Outcome) -> Void = { _ in }

    /// Installs the event monitors. `preview` receives the
    /// live label text on every change; `hint` carries the
    /// transient one-key notice (nil clears it); `finish`
    /// fires exactly once (teardown resets it to a no-op
    /// first).
    func start(
        preview: @escaping (String) -> Void,
        hint: @escaping (String?) -> Void = { _ in },
        finish: @escaping (Outcome) -> Void
    ) {
        stop()
        onPreview = preview
        onHint = hint
        onFinish = finish
        keyMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            // A nil self must never swallow the app's keys —
            // the leaked monitor would eat every keystroke.
            guard let self else { return event }
            let kind: EventKind =
                switch event.type {
                case .keyDown: .keyDown
                case .keyUp: .keyUp
                default: .flagsChanged
                }
            let swallow = self.handle(
                kind,
                keyCode: event.keyCode,
                flags: event.modifierFlags
            )
            return swallow ? nil : event
        }
        // Clicking anywhere cancels (the native recorder
        // idiom); the event passes through so the click still
        // lands.
        mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.finish(.clickAway)
            return event
        }
        deactivation = NotificationCenter.default.addObserver(
            forName: NSApplication
                .didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.finish(.cancelled)
            }
        }
    }

    /// Silent teardown — no `finish` callback (the closures
    /// reset to no-ops, making the exactly-once contract
    /// structural). Used when the coordinator hands the
    /// recording to another field or the row disappears.
    func stop() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        mouseMonitor = nil
        if let deactivation {
            NotificationCenter.default.removeObserver(
                deactivation
            )
        }
        deactivation = nil
        heldKeys = []
        pending = nil
        onPreview = { _ in }
        onHint = { _ in }
        onFinish = { _ in }
    }

    private func finish(_ outcome: Outcome) {
        let callback = onFinish
        stop()
        callback(outcome)
    }

    // MARK: - The state machine (testable seam)

    /// Feeds one key event through the chord logic. Returns
    /// whether the event should be swallowed. Internal so
    /// tests can drive sequences without `NSEvent`.
    @discardableResult
    func handle(
        _ kind: EventKind,
        keyCode: UInt16,
        flags: NSEvent.ModifierFlags
    ) -> Bool {
        switch kind {
        case .keyDown:
            return keyDown(keyCode: keyCode, flags: flags)
        case .keyUp:
            // Swallow only the keyUp of a keyDown we
            // swallowed — a key held from before the
            // recording started belongs to its original
            // responder.
            let tracked =
                heldKeys.remove(keyCode) != nil
            tryLockIn(flags: flags)
            return tracked
        case .flagsChanged:
            // Modifiers only accumulate while a base key is
            // held — releases never downgrade the chord.
            if pending != nil, !heldKeys.isEmpty {
                pending?.accumulate(flags)
            }
            publishPreview(flags: flags)
            tryLockIn(flags: flags)
            return false
        }
    }

    private func keyDown(
        keyCode: UInt16,
        flags: NSEvent.ModifierFlags
    ) -> Bool {
        let bareEscape =
            keyCode == 53
            && !flags.contains(.command)
            && !flags.contains(.option)
            && !flags.contains(.control)
            && !flags.contains(.shift)
        if bareEscape {
            finish(.cancelled)
            return true
        }
        // A keyDown for a key already held is the OS
        // auto-repeat: swallow it without touching the
        // pending chord or the hint — a repeat must neither
        // re-snapshot to the overlapped key (defeating
        // first-wins) nor rebuild the chord from the current
        // flags (stripping accumulated modifiers).
        if heldKeys.contains(keyCode) {
            return true
        }
        // A second base key while the first is still held is
        // a chord attempt — a shortcut is modifiers + ONE key
        // (Carbon can't register more). Keep the first key,
        // teach instead of silently switching; the new key
        // still counts as held so the lock-in waits for its
        // release too.
        if pending != nil, !heldKeys.isEmpty,
            !heldKeys.contains(keyCode)
        {
            heldKeys.insert(keyCode)
            onHint(
                "Only one key besides modifiers — release "
                    + "it first to switch."
            )
            return true
        }
        heldKeys.insert(keyCode)
        // The snapshot: key + the modifiers held right now.
        pending = Pending(
            keyCode: UInt32(keyCode),
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            shift: flags.contains(.shift)
        )
        onHint(nil)
        publishPreview(flags: flags)
        return true
    }

    /// The lock-in: everything released, a chord pending.
    private func tryLockIn(flags: NSEvent.ModifierFlags) {
        guard heldKeys.isEmpty,
            !flags.contains(.command),
            !flags.contains(.option),
            !flags.contains(.control),
            !flags.contains(.shift),
            let pending
        else { return }
        if let combo = pending.combo {
            finish(.chord(combo))
        } else {
            finish(.cancelled)
        }
    }

    // MARK: - Preview

    private func publishPreview(
        flags: NSEvent.ModifierFlags
    ) {
        if let combo = pending?.combo,
            let parsed = KeyCombo.parse(combo)
        {
            onPreview(
                ComboSymbols.render(
                    parsed,
                    layoutChar: LayoutKeyGlyph.char
                )
            )
        } else {
            onPreview(Self.modifierSymbols(flags))
        }
    }

    /// The held modifiers in display order (⌃⌥⇧⌘). A
    /// modifier-only chord is not recordable (Carbon hotkeys
    /// need a base key) — the preview makes that visible.
    static func modifierSymbols(
        _ flags: NSEvent.ModifierFlags
    ) -> String {
        var symbols = ""
        if flags.contains(.control) { symbols += "⌃" }
        if flags.contains(.option) { symbols += "⌥" }
        if flags.contains(.shift) { symbols += "⇧" }
        if flags.contains(.command) { symbols += "⌘" }
        return symbols
    }
}
