import AppKit
import KiwiDeskCore

/// Key combination recording engine: snap-in on key-down (#212,
/// replacing #68's lock-on-full-release machine). Bare Escape
/// cancels but Escape WITH modifiers records — ⌃Escape is a
/// valid hotkey; any click cancels (the field absorbs it); app
/// deactivation cancels too, since a system chord (⌘Tab) steals
/// focus mid-recording (`ChordRecorderTests`). In `.modifiers`
/// mode (a scroll gesture's chord, #1656) keys are ignored and the
/// largest modifier set held at once commits when all are released.
/// In `.sourceKey` mode (the Hyper key, #1870) the first physical
/// key pressed commits, a modifier by its own sided key code.
/// With Hyper on, `.combo` mode reads the remapped key's F18 as
/// the `hyper` modifier while it is held (#1870).
@MainActor
final class ChordRecorder {
    enum Outcome {
        /// A non-modifier key was pressed — the combo locks.
        case chord(String)
        /// `.modifiers` mode: every modifier was released.
        case modifiers(ScrollChord)
        /// `.sourceKey` mode: the key code pressed, a modifier's
        /// carrying its side (Right ⌘ 54, Left ⌘ 55).
        case sourceKey(UInt16)
        /// Bare Escape or app deactivation.
        case cancelled
        /// A mouse click ended the recording.
        case clickAway
    }

    enum Mode {
        /// A key plus modifiers, locked on the key.
        case combo
        /// Modifiers alone, locked on the last release.
        case modifiers
        /// One physical key, locked on its press.
        case sourceKey
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
    private(set) var mode = Mode.combo
    /// `.modifiers` mode: the largest set held so far.
    private var heldMost: NSEvent.ModifierFlags = []
    /// `.combo` mode: whether F18 is the Hyper key, and held.
    private var hyperOn = false
    private var hyperHeld = false
    var onPreview: (String) -> Void = { _ in }
    var onFinish: (Outcome) -> Void = { _ in }
    var isSuppressingKeyUp: Bool { releaseMonitor != nil }

    /// Installs event monitors for keyboard and click-away cancellation.
    func start(
        mode: Mode = .combo,
        hyper: Bool = false,
        preview: @escaping (String) -> Void,
        finish: @escaping (Outcome) -> Void
    ) {
        stop()
        self.mode = mode
        heldMost = []
        hyperOn = hyper
        hyperHeld = false
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
            if mode == .combo, hyperOn, keyCode == Self.hyperCode {
                hyperHeld = true
                onPreview(previewSymbols(flags))
                return true
            }
            if keyCode == 53, held.isEmpty, !hyperHeld {
                finish(.cancelled)
                return true
            }
            if mode == .sourceKey {
                finish(.sourceKey(keyCode))
                return true
            }
            guard mode == .combo else { return true }
            guard
                let combo = KeyCombo.comboString(
                    keyCode: UInt32(keyCode),
                    command: flags.contains(.command),
                    option: flags.contains(.option),
                    control: flags.contains(.control),
                    shift: flags.contains(.shift),
                    hyper: hyperHeld
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
            if keyCode == Self.hyperCode, hyperHeld {
                hyperHeld = false
                onPreview(previewSymbols(flags))
            }
            return consumeSuppressedKeyUp(keyCode)
        case .flagsChanged:
            if mode == .sourceKey {
                // A modifier's press, never its release: its OWN
                // side's device bit is down — the shared `.command`
                // flag stays set while the other side is held.
                guard let mask = Self.sideMask[keyCode],
                    mask == 0 || flags.rawValue & mask != 0
                else { return true }
                finish(.sourceKey(keyCode))
                return true
            }
            guard mode == .modifiers else {
                onPreview(previewSymbols(flags))
                return false
            }
            return modifiersChanged(flags)
        }
    }

    /// `.modifiers` mode: tracks the largest set, previews what is
    /// held, and commits once nothing is.
    private func modifiersChanged(_ flags: NSEvent.ModifierFlags) -> Bool {
        let held = flags.intersection([.command, .option, .control, .shift])
        if held.rawValue.nonzeroBitCount > heldMost.rawValue.nonzeroBitCount {
            heldMost = held
        }
        guard held.isEmpty else {
            onPreview(Self.modifierSymbols(held))
            return false
        }
        if !heldMost.isEmpty {
            finish(.modifiers(Self.scrollChord(heldMost)))
        }
        return false
    }

    /// The key code the Hyper key arrives as (`HyperKeyRemap`).
    static let hyperCode = HyperSourceKey.trigger.keyCode

    /// `.combo` mode's preview: the held modifiers, Hyper leading.
    private func previewSymbols(_ flags: NSEvent.ModifierFlags) -> String {
        (hyperHeld ? ComboSymbols.hyperGlyph : "")
            + Self.modifierSymbols(flags)
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
