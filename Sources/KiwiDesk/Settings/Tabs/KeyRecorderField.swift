import AppKit
import KiwiDeskCore
import SwiftUI

/// The right-hand column of every keybinding row: a recorder
/// that captures the next key press into a canonical combo
/// string, with a conflict indicator and a clear button.
///
/// Coordination (#33): at most one recorder is active — the
/// shared `RecorderCoordinator` snaps the previous field back
/// the instant a new one starts. Duplicates (#34): when
/// `preflight` reports the combo is taken by another KiwiDesk
/// row, the recording is rejected with a red flash and inline
/// Steal / Go to actions instead of committing a silent
/// duplicate.
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
    @State private var monitor: Any?
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
        .onChange(of: coordinator.active) { _, active in
            // Another field started recording — snap back.
            if active != fieldID { removeMonitor() }
        }
        .onDisappear(perform: stop)
    }

    // MARK: - Rejection UI (#34)

    private func rejectionRow(
        _ rejection: RecorderRejection
    ) -> some View {
        HStack(spacing: 6) {
            Text("Assigned to \u{201C}\(rejection.holder)\u{201D}")
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
        if recording { return "Press keys…" }
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
        recording ? stop() : start()
    }

    private func start() {
        rejection = nil
        // Claiming the coordinator snaps back whichever field
        // was recording before (#33).
        coordinator.active = fieldID
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { event in
            handle(event)
            return nil
        }
    }

    private func stop() {
        removeMonitor()
        if coordinator.active == fieldID {
            coordinator.active = nil
        }
    }

    private func removeMonitor() {
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
