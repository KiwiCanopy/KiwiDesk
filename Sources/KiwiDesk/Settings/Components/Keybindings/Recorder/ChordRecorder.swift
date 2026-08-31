import AppKit
import KiwiDeskCore

/// Key combination recording engine: snap-in on key-down (#212,
/// replacing #68's lock-on-full-release machine). Bare Escape
/// cancels but Escape WITH modifiers records — ⌃Escape is a
/// valid hotkey; any click cancels (the field absorbs it); app
/// deactivation cancels too, since a system chord (⌘Tab) steals
/// focus mid-recording (`ChordRecorderTests`).
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

    /// Installs event monitors for keyboard and click-away cancellation.
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
            // A nil self must never swallow the app's keys — the
            // leaked monitor would eat every keystroke.
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

    /// State machine processing key events (`ChordRecorderTests`).
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
                return true
            }
            finish(.chord(combo))
            return true
        case .keyUp:
            // Only releases paired with swallowed keyDowns are
            // ours — a key held before recording still passes to
            // its original responder.
            return consumeSuppressedKeyUp(keyCode)
        case .flagsChanged:
            onPreview(Self.modifierSymbols(flags))
            return false
        }
    }

    /// Formats held modifiers in standard display order (⌃⌥⇧⌘).
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

    /// Suppresses trailing key-up events following recording completion.
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
