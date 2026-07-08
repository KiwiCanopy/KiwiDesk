import AppKit
import KiwiDeskCore
import SwiftUI

/// The right-hand column of every keybinding row: a recorder
/// that captures the next key press into a canonical combo
/// string, with a conflict indicator and a clear button.
///
/// Coordination (#33): at most one recorder is active — the
/// shared `RecorderCoordinator` tears the previous field down
/// synchronously when a new one starts. Duplicates (#34): when
/// `preflight` reports the combo is taken by another KiwiDesk
/// row, the recording is rejected with a red flash and inline
/// Steal / Go to actions instead of committing a silent
/// duplicate. While recording, held modifiers preview live in
/// the field, and a click anywhere else cancels the recording.
///
/// ShortcutsSection-private: requires a `RecorderCoordinator`
/// in the environment (`.environmentObject`) — rendering it
/// outside that tree is a programmer error and will crash.
struct KeyRecorderField: View {
    let combo: String
    /// Conflict tooltip; nil when the combo is unique + valid.
    var conflict: String?
    /// KiwiDesk-collision check run before committing; nil
    /// commits unconditionally (no other rows to collide
    /// with).
    var preflight: ((String) -> RecorderRejection?)? = nil
    let onRecord: (String) -> Void
    let onClear: () -> Void

    @EnvironmentObject private var coordinator: RecorderCoordinator
    @State private var fieldID = UUID()
    @State private var keyMonitor: Any?
    @State private var mouseMonitor: Any?
    /// Live preview of the modifiers currently held (#68
    /// recorder UX): "⌃⌥⌘" while the chord is being formed.
    @State private var heldModifiers = ""
    /// Set when a click-away cancelled the recording — the
    /// button's own click lands right after the mouse monitor,
    /// and must not immediately restart it.
    @State private var cancelledByClick: Date?
    @State private var rejection: RecorderRejection?
    @State private var flashing = false

    private var recording: Bool {
        coordinator.active == fieldID
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                if let conflict {
                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    .help(conflict)
                }
                Button(action: toggle) {
                    Text(label)
                        .frame(minWidth: 110)
                        .monospaced()
                }
                .buttonStyle(.bordered)
                .tint(buttonTint)
                if !combo.isEmpty && !recording {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            if let rejection {
                rejectionRow(rejection)
            }
        }
        .onChange(of: coordinator.generation) { _, _ in
            // The edited mode/target changed — any pending
            // rejection captured stale bindings (#68 review).
            rejection = nil
            removeMonitors()
        }
        .onDisappear(perform: stop)
    }

    // MARK: - Rejection UI (#34)

    private func rejectionRow(
        _ rejection: RecorderRejection
    ) -> some View {
        HStack(spacing: 6) {
            Text(
                "Assigned to \u{201C}\(rejection.holder)\u{201D}"
            )
            .foregroundStyle(.red)
            Button("Steal") {
                self.rejection = nil
                rejection.steal()
            }
            Button("Go to") {
                self.rejection = nil
                coordinator.scrollTarget =
                    rejection.holderRowID
            }
            Button {
                self.rejection = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .font(.caption)
        .buttonStyle(.link)
    }

    private var buttonTint: Color? {
        if flashing { return .red }
        return recording ? .accentColor : nil
    }

    private var label: String {
        if recording {
            return heldModifiers.isEmpty
                ? "Press keys…" : heldModifiers + "…"
        }
        guard !combo.isEmpty else { return "Record" }
        // Show the shortcut as native macOS glyphs, mapped
        // through the active keyboard layout (#23). The stored
        // combo stays the canonical word form; only the display
        // changes, so a parse failure just shows the raw
        // string.
        guard let parsed = KeyCombo.parse(combo) else {
            return combo
        }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }

    // MARK: - Recording lifecycle

    private func toggle() {
        // A click-away cancel fires the mouse monitor first;
        // when the click was on this very button, the action
        // arriving now must not restart the recording — the
        // net effect of that click is "stop", like before.
        if let cancelled = cancelledByClick,
            Date().timeIntervalSince(cancelled) < 0.3
        {
            cancelledByClick = nil
            return
        }
        recording ? stop() : start()
    }

    private func start() {
        rejection = nil
        heldModifiers = ""
        // Claiming tears down whichever field was recording
        // before — synchronously, so two keyDown monitors
        // never coexist (#33). The teardown closure writes
        // through the State bindings, not `self` (structs
        // captured by value would mutate a stale copy).
        let key = $keyMonitor
        let mouse = $mouseMonitor
        let held = $heldModifiers
        coordinator.claim(fieldID) {
            if let monitor = key.wrappedValue {
                NSEvent.removeMonitor(monitor)
            }
            key.wrappedValue = nil
            if let monitor = mouse.wrappedValue {
                NSEvent.removeMonitor(monitor)
            }
            mouse.wrappedValue = nil
            held.wrappedValue = ""
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { event in
            if event.type == .flagsChanged {
                heldModifiers = Self.modifierSymbols(
                    event.modifierFlags
                )
                return event
            }
            handle(event)
            return nil
        }
        // Clicking anywhere else cancels the recording (the
        // native recorder idiom); the event passes through so
        // the click still lands.
        mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { event in
            cancelledByClick = Date()
            stop()
            return event
        }
    }

    private func stop() {
        removeMonitors()
        coordinator.release(fieldID)
    }

    private func removeMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        mouseMonitor = nil
        heldModifiers = ""
    }

    /// The held modifiers in display order (⌃⌥⇧⌘) for the
    /// live preview. Modifier-only combos are not recordable
    /// (Carbon hotkeys need a base key); the preview makes
    /// that visible instead of confusing.
    private static func modifierSymbols(
        _ flags: NSEvent.ModifierFlags
    ) -> String {
        var symbols = ""
        if flags.contains(.control) { symbols += "⌃" }
        if flags.contains(.option) { symbols += "⌥" }
        if flags.contains(.shift) { symbols += "⇧" }
        if flags.contains(.command) { symbols += "⌘" }
        return symbols
    }

    /// Escape with no modifiers cancels; any other key becomes
    /// the combo (bare keys are allowed for modal bindings).
    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags
        let command = flags.contains(.command)
        let option = flags.contains(.option)
        let control = flags.contains(.control)
        let shift = flags.contains(.shift)
        let bareEscape =
            event.keyCode == 53
            && !command && !option && !control && !shift
        if bareEscape {
            stop()
            return
        }
        if let string = KeyCombo.comboString(
            keyCode: UInt32(event.keyCode),
            command: command,
            option: option,
            control: control,
            shift: shift
        ) {
            commit(string)
        }
        stop()
    }

    /// Hard-blocks a KiwiDesk duplicate (#34); anything else
    /// commits (a macOS system shortcut stays the soft per-row
    /// ⚠ — shadowing one can be intentional).
    private func commit(_ string: String) {
        if let found = preflight?(string) {
            rejection = found
            flash()
            return
        }
        onRecord(string)
    }

    private func flash() {
        flashing = true
        Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: 500_000_000
            )
            flashing = false
        }
    }
}
