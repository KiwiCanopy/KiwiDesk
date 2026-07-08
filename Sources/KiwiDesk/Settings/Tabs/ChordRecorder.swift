import AppKit
import KiwiDeskCore

/// The chord-capture engine behind `KeyRecorderField` (#68
/// recorder UX): lock-on-full-release with a lazily honest
/// preview. The pending combo mirrors what is held; a
/// release stashes the chord as the burst candidate, and for
/// `releaseWindow` the DISPLAY keeps showing that chord —
/// lock-in usually completes inside the window, and an
/// instant downgrade made the combo visibly vanish right
/// before it locked. Only when the window closes without a
/// lock does the preview settle to what is actually held
/// (`settleBurst`), the recording still live for re-entry.
///
/// Rules:
/// - A base keyDown starts the pending combo (key + held
///   modifiers); modifier changes mirror into it, both
///   directions. Pressing another key after a release
///   re-enters — correction is ⌘J, J up, K down → ⌘K.
/// - A second base key WHILE the first is held is a chord
///   attempt: the first key wins, a one-key hint teaches (a
///   shortcut is modifiers + one key).
/// - Full release locks the freshest burst candidate; a key
///   that starts a new chord, or an added modifier, discards
///   it. (A chord-attempt overlap does NOT — the first key
///   wins, so its stashed chord stays lockable.)
/// - Bare Escape cancels. Any mouse click cancels
///   (`.clickAway`, so the field can absorb the click on its
///   own button). App deactivation cancels too — a system
///   chord (⌘Tab, ⌘⇧4) steals its keyUps, which would
///   otherwise leave `heldKeys` stuck and the recorder
///   un-lockable.
///
/// The state machine (`handle(_:keyCode:flags:)`, in
/// `ChordRecorder+Machine.swift`) is driven by
/// `ChordRecorderTests` without `NSEvent`s; this file is the
/// monitor shell and lifecycle. Stored state is internal (not
/// `private`, which is file-scoped) for that split — nothing
/// outside the two files and the tests may touch it.
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
    /// disassembly. Display freeze and lockability are
    /// deliberately the SAME window — split the knob and the
    /// preview either shows a chord that can no longer lock
    /// or hides one that still can.
    static let releaseWindow: TimeInterval = 0.35

    /// Scheduling slack on top of `releaseWindow`, so the
    /// settle Task always wakes on the expired side of the
    /// window it re-checks.
    static let settleSlack: TimeInterval = 0.03

    /// Injectable clock — tests drive expiry without
    /// sleeping.
    var now: () -> Date = Date.init

    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var deactivation: (any NSObjectProtocol)?
    var heldKeys: Set<UInt16> = []
    var pending: PendingChord?
    var candidate: BurstCandidate?
    var lastFlags: NSEvent.ModifierFlags = []
    var onPreview: (String, String?) -> Void = { _, _ in }
    var onHint: (String?) -> Void = { _ in }
    var onFinish: (Outcome) -> Void = { _ in }

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

    func finish(_ outcome: Outcome) {
        let callback = onFinish
        stop()
        callback(outcome)
    }
}
