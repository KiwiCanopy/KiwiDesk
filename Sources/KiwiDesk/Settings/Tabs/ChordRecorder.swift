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
///   key re-snapshots — you can correct mid-chord (⌘J → ⌘K).
/// - While a base key is held, added modifiers ACCUMULATE
///   into the pending combo; dropped ones are ignored — an
///   early modifier release can't strip the chord.
/// - Bare Escape cancels. Any mouse click cancels
///   (`.clickAway`, so the field can absorb the click on its
///   own button).
@MainActor
final class ChordRecorder {
    enum Outcome {
        /// Every key released — the chord locks in.
        case chord(String)
        /// Bare Escape (or an unrepresentable key).
        case cancelled
        /// A mouse click ended the recording.
        case clickAway
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
    private var heldKeys: Set<UInt16> = []
    private var pending: Pending?
    private var onPreview: (String) -> Void = { _ in }
    private var onFinish: (Outcome) -> Void = { _ in }

    /// Installs the event monitors. `preview` receives the
    /// live label text on every change; `finish` fires exactly
    /// once (the monitors are torn down first).
    func start(
        preview: @escaping (String) -> Void,
        finish: @escaping (Outcome) -> Void
    ) {
        stop()
        heldKeys = []
        pending = nil
        onPreview = preview
        onFinish = finish
        keyMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            self?.handle(event)
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
    }

    /// Silent teardown — no `finish` callback. Used when the
    /// coordinator hands the recording to another field or
    /// the row disappears.
    func stop() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        mouseMonitor = nil
        heldKeys = []
        pending = nil
    }

    private func finish(_ outcome: Outcome) {
        let callback = onFinish
        stop()
        callback(outcome)
    }

    // MARK: - Event handling

    private func handle(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .keyDown:
            return keyDown(event)
        case .keyUp:
            heldKeys.remove(event.keyCode)
            tryLockIn(flags: event.modifierFlags)
            // Swallow the keyUp of a swallowed keyDown.
            return nil
        case .flagsChanged:
            flagsChanged(event)
            return event
        default:
            return event
        }
    }

    private func keyDown(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags
        let bareEscape =
            event.keyCode == 53
            && !flags.contains(.command)
            && !flags.contains(.option)
            && !flags.contains(.control)
            && !flags.contains(.shift)
        if bareEscape {
            finish(.cancelled)
            return nil
        }
        heldKeys.insert(event.keyCode)
        // The snapshot: key + the modifiers held right now.
        pending = Pending(
            keyCode: UInt32(event.keyCode),
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            shift: flags.contains(.shift)
        )
        publishPreview(flags: flags)
        return nil
    }

    private func flagsChanged(_ event: NSEvent) {
        // Modifiers only accumulate while a base key is held
        // — releases never downgrade the pending chord.
        if pending != nil, !heldKeys.isEmpty {
            pending?.accumulate(event.modifierFlags)
        }
        publishPreview(flags: event.modifierFlags)
        tryLockIn(flags: event.modifierFlags)
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
