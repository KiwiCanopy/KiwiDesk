import AppKit
import KiwiDeskCore

/// The capture engine behind `KeyRecorderField` (#212):
/// **snap-in on key-down**. Modifiers can be pressed and
/// released freely — the preview mirrors what is held — and
/// the first non-modifier keyDown locks the combo instantly
/// (that key plus the modifiers held at that moment), the way
/// the native System Settings shortcut recorder reads.
/// Correction is re-recording (one click); there is no
/// release choreography. Replaces the lock-on-full-release
/// machine (#68), whose burst window, stashed candidate, and
/// mid-chord correction proved buggier than the model they
/// enabled.
///
/// Rules:
/// - `flagsChanged` only updates the modifier preview (⌃⌥⇧⌘,
///   display order). A modifier-only chord is not recordable
///   (Carbon hotkeys need a base key) — the preview makes
///   that visible.
/// - A keyDown locks `held modifiers + key` and finishes. A
///   key `KeyCombo` cannot represent is swallowed and the
///   recording continues.
/// - Bare Escape cancels (Escape WITH modifiers records —
///   ⌃Escape is a valid hotkey). Any mouse click cancels
///   (`.clickAway`, so the field can absorb the click on its
///   own button). App deactivation cancels too — a system
///   chord (⌘Tab, ⌘⇧4) would steal focus mid-recording.
///
/// The state machine (`handle(_:keyCode:flags:)`) is internal
/// so `ChordRecorderTests` can drive it without `NSEvent`s.
@MainActor
final class ChordRecorder {
    enum Outcome {
        /// A non-modifier key was pressed — the combo locks.
        case chord(String)
        /// Bare Escape or app deactivation.
        case cancelled
        /// A mouse click ended the recording.
        case clickAway
    }

    enum EventKind {
        case keyDown
        case keyUp
        case flagsChanged
    }

    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var releaseMonitor: Any?
    private var releaseTimeout: Task<Void, Never>?
    private var deactivation: (any NSObjectProtocol)?
    private var suppressedKeyUps: Set<UInt16> = []
    var onPreview: (String) -> Void = { _ in }
    var onFinish: (Outcome) -> Void = { _ in }
    var isSuppressingKeyUp: Bool { releaseMonitor != nil }

    /// Installs the event monitors. `preview` receives the
    /// held-modifier symbols on every change; `finish` fires
    /// exactly once (teardown resets it to a no-op first).
    func start(
        preview: @escaping (String) -> Void,
        finish: @escaping (Outcome) -> Void
    ) {
        stop()
        onPreview = preview
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

    func stop() {
        stopCapture()
        beginReleaseSuppression()
        onPreview = { _ in }
        onFinish = { _ in }
    }

    private func stopCapture() {
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
    }

    func finish(_ outcome: Outcome) {
        let callback = onFinish
        stopCapture()
        onPreview = { _ in }
        onFinish = { _ in }
        beginReleaseSuppression()
        callback(outcome)
    }

    // MARK: - The state machine (testable seam)

    /// Feeds one key event through the snap-in logic. Returns
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
            let held = flags.intersection([
                .command, .option, .control, .shift,
            ])
            // Every swallowed keyDown owns its matching keyUp;
            // never leak an orphan release to the focused
            // control after recorder teardown.
            suppressedKeyUps.insert(keyCode)
            if keyCode == 53, held.isEmpty {
                finish(.cancelled)
                return true
            }
            guard
                let combo = KeyCombo.comboString(
                    keyCode: UInt32(keyCode),
                    command: flags.contains(.command),
                    option: flags.contains(.option),
                    control: flags.contains(.control),
                    shift: flags.contains(.shift)
                )
            else {
                // Unrepresentable key: swallow it, keep
                // recording — the preview still shows the
                // held modifiers.
                return true
            }
            finish(.chord(combo))
            return true
        case .keyUp:
            // Only releases paired with swallowed keyDowns are
            // ours. A key held before recording still passes to
            // its original responder.
            return consumeSuppressedKeyUp(keyCode)
        case .flagsChanged:
            onPreview(Self.modifierSymbols(flags))
            return false
        }
    }

    /// The held modifiers in display order (⌃⌥⇧⌘).
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

    /// After a lock/cancel tears down the capture monitor, keep
    /// a narrow keyUp-only monitor until every swallowed press
    /// releases. Timeout bounds the lifetime if macOS steals a
    /// release while focus changes.
    private func beginReleaseSuppression() {
        guard !suppressedKeyUps.isEmpty else { return }
        if let releaseMonitor {
            NSEvent.removeMonitor(releaseMonitor)
        }
        releaseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyUp
        ) { [self] event in
            consumeSuppressedKeyUp(event.keyCode) ? nil : event
        }
        releaseTimeout?.cancel()
        releaseTimeout = Task { @MainActor [self] in
            try? await Task.sleep(
                nanoseconds: 2_000_000_000
            )
            guard !Task.isCancelled else { return }
            clearReleaseSuppression()
        }
    }

    private func consumeSuppressedKeyUp(
        _ keyCode: UInt16
    ) -> Bool {
        guard suppressedKeyUps.remove(keyCode) != nil else {
            return false
        }
        if suppressedKeyUps.isEmpty {
            clearReleaseSuppression()
        }
        return true
    }

    private func clearReleaseSuppression() {
        if let releaseMonitor {
            NSEvent.removeMonitor(releaseMonitor)
        }
        releaseMonitor = nil
        releaseTimeout?.cancel()
        releaseTimeout = nil
        suppressedKeyUps = []
    }
}
