import AppKit
import KiwiDeskCore

/// The chord-capture engine behind `KeyRecorderField` (#68
/// recorder UX): lock-on-full-release with a live preview.
/// The pending combo MIRRORS what is held right now — a
/// released key or modifier leaves the preview immediately —
/// while a release-burst candidate keeps staggered releases
/// honest: the first release that downgrades a chord stashes
/// it, and if everything is up within `releaseWindow` the
/// stashed chord locks (⌘ let go a split second before J
/// still locks ⌘J). A slower disassembly expires the stash:
/// the preview has long shown the smaller truth, so nothing
/// locks and the field keeps recording, ready for re-entry.
///
/// Rules:
/// - A base keyDown starts the pending combo (key + the
///   modifiers held at that moment); modifier changes while
///   it is held mirror into it, both directions.
/// - Releasing the base key clears the pending combo (the
///   preview drops to the held modifiers) and stashes the
///   chord as the burst candidate. Pressing another key
///   re-enters — you can correct mid-chord (⌘J, J up,
///   K down → ⌘K).
/// - A second base key pressed WHILE the first is still held
///   is a chord attempt: the pending combo keeps the first
///   key and the field shows a one-key hint instead of
///   silently switching (a shortcut is modifiers + one key).
/// - Full release locks the freshest burst candidate; a
///   pressed key or added modifier discards it (a new chord
///   is being built).
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

    /// Releasing a whole chord is a burst of events well
    /// under this; anything slower is a deliberate
    /// disassembly the preview has already shown.
    static let releaseWindow: TimeInterval = 0.35

    /// Injectable clock — tests drive expiry without
    /// sleeping.
    var now: () -> Date = Date.init

    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var deactivation: (any NSObjectProtocol)?
    private var heldKeys: Set<UInt16> = []
    private var pending: PendingChord?
    private var candidate: BurstCandidate?
    private var lastFlags: NSEvent.ModifierFlags = []
    private var onPreview: (String, String?) -> Void = {
        _,
        _ in
    }
    private var onHint: (String?) -> Void = { _ in }
    private var onFinish: (Outcome) -> Void = { _ in }

    /// Installs the event monitors. `preview` receives the
    /// live label text on every change; `hint` carries the
    /// transient one-key notice (nil clears it); `finish`
    /// fires exactly once (teardown resets it to a no-op
    /// first).
    func start(
        preview: @escaping (String, String?) -> Void,
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
        candidate = nil
        lastFlags = []
        onPreview = { _, _ in }
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
            if let held = pending,
                held.keyCode == UInt32(keyCode)
            {
                // The base key left: stash the chord for the
                // burst window, mirror the release into the
                // preview.
                stashCandidate(held)
                pending = nil
            }
            publishPreview(flags: flags)
            tryLockIn(flags: flags)
            return tracked
        case .flagsChanged:
            defer { lastFlags = flags }
            if var held = pending {
                let before = held
                held.mirror(flags)
                if held.lostModifier(since: before) {
                    // A modifier left mid-chord: preview
                    // downgrades, the burst stash keeps the
                    // fuller chord lockable.
                    stashCandidate(before)
                } else if before.lostModifier(since: held) {
                    // A modifier JOINED — a new chord is
                    // being built over any stashed one.
                    candidate = nil
                }
                pending = held
            } else if flags.subtracting(lastFlags)
                .intersection([
                    .command, .option, .control, .shift,
                ]) != []
            {
                candidate = nil
            }
            publishPreview(flags: flags)
            tryLockIn(flags: flags)
            return false
        }
    }

    /// Keeps the chord a release just downgraded — only the
    /// burst's FIRST downgrade: a fresh candidate is never
    /// overwritten (the fullest chord wins), an expired one
    /// is replaced by the live truth.
    private func stashCandidate(_ pending: PendingChord) {
        if let candidate,
            now().timeIntervalSince(candidate.at)
                < Self.releaseWindow
        {
            return
        }
        guard let combo = pending.combo else { return }
        candidate = BurstCandidate(combo: combo, at: now())
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
        // A fresh key discards any stashed burst chord — the
        // user is building a new one.
        candidate = nil
        // The snapshot: key + the modifiers held right now.
        pending = PendingChord(
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

    /// The lock-in: everything released. A fresh burst
    /// candidate locks; an expired one is discarded and the
    /// recording continues with an honest, empty preview —
    /// the user disassembled the chord slowly and can simply
    /// re-enter.
    private func tryLockIn(flags: NSEvent.ModifierFlags) {
        guard heldKeys.isEmpty,
            !flags.contains(.command),
            !flags.contains(.option),
            !flags.contains(.control),
            !flags.contains(.shift),
            let candidate
        else { return }
        self.candidate = nil
        if now().timeIntervalSince(candidate.at)
            < Self.releaseWindow
        {
            finish(.chord(candidate.combo))
        } else {
            onPreview("", nil)
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
                ),
                combo
            )
        } else {
            onPreview(Self.modifierSymbols(flags), nil)
        }
    }
}
