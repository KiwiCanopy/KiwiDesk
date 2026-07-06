import AppKit
import KiwiDeskCore
import SwiftUI

/// The right-hand column of every keybinding row: a recorder
/// that captures the next key press into a canonical combo
/// string, with a conflict indicator and a clear button
/// (05_GUI_Concept §2, Tab 5).
struct KeyRecorderField: View {
    let combo: String
    /// Conflict tooltip; nil when the combo is unique + valid.
    var conflict: String?
    let onRecord: (String) -> Void
    let onClear: () -> Void

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            if let conflict {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(conflict)
            }
            Button(action: toggle) {
                Text(label)
                    .frame(minWidth: 110)
                    .monospaced()
            }
            .buttonStyle(.bordered)
            .tint(recording ? .accentColor : nil)
            if !combo.isEmpty && !recording {
                Button(action: clear) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .onDisappear(perform: stop)
    }

    private var label: String {
        if recording { return "Press keys…" }
        guard !combo.isEmpty else { return "Record" }
        // Show the shortcut as native macOS glyphs, mapped through
        // the active keyboard layout (#23). The stored combo stays
        // the canonical word form; only the display changes, so a
        // parse failure just shows the raw string.
        guard let parsed = KeyCombo.parse(combo) else { return combo }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }

    private func toggle() {
        recording ? stop() : start()
    }

    private func clear() {
        onClear()
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { event in
            handle(event)
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
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
            onRecord(string)
        }
        stop()
    }
}
