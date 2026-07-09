import AppKit
import KiwiDeskCore
import SwiftUI

/// The right-hand column of every keybinding row: a recorder
/// that captures a chord into a canonical combo string, with a
/// conflict indicator and a clear button.
///
/// Recording is lock-on-full-release (`ChordRecorder`): the
/// field live-previews the chord as it is formed (modifiers,
/// then the full combo) and locks in when every key is
/// released — press order and release timing can never corrupt
/// the chord, and the base key can be corrected mid-chord.
/// Coordination (#33): at most one recorder is active — the
/// shared `RecorderCoordinator` tears the previous field down
/// synchronously when a new one starts. Duplicates (#34):
/// when `preflight` reports the combo is taken by another
/// KiwiDesk row, the lock-in is rejected with a red flash and
/// inline Steal / Go to actions instead of committing a
/// silent duplicate.
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
    @State private var recorder = ChordRecorder()
    /// Live preview of the chord being formed ("⌃⌥", then
    /// "⌃⌥⌘K") while recording.
    @State private var preview = ""
    /// Set when a click-away cancelled the recording — the
    /// button's own click lands right after the mouse monitor,
    /// and must not immediately restart it.
    @State private var cancelledByClick: Date?
    @State private var rejection: RecorderRejection?
    /// Transient one-key notice (a second key pressed while
    /// the first was still held).
    @State private var hint: String?
    /// The holder of the combo currently being formed, shown
    /// live while recording (in-app rows only — the macOS
    /// system-shortcut check would go stale, so it stays the
    /// per-row warning after commit).
    @State private var takenBy: String?
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
                recordButton
                if !combo.isEmpty && !recording {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            if let rejection = liveRejection {
                rejectionRow(rejection)
            }
            if recording, let takenBy {
                Text(
                    L(
                        "key_recorder.already_used",
                        "Already used by \u{201C}%1$@\u{201D}"
                            + " — locking in will ask to "
                            + "replace.",
                        takenBy
                    )
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onChange(of: coordinator.generation) { _, _ in
            // The edited mode/target changed — any pending
            // rejection captured stale bindings (#68 review).
            rejection = nil
            recorder.stop()
            preview = ""
            hint = nil
            takenBy = nil
        }
        .onChange(of: liveRejection == nil) { _, clear in
            // The latch follows the live check out: once the
            // conflict is fixed anywhere, a later collision on
            // the same combo must not resurrect this row.
            if clear { rejection = nil }
        }
        .onDisappear(perform: stop)
    }

    /// Extracted from `body` — the full modifier chain in one
    /// expression blew the type-checker's budget on CI.
    ///
    /// The engagement halo: while recording, an accent fill +
    /// ring extend slightly past the button so the one armed
    /// field among dozens of recorder rows reads at a glance —
    /// the tint alone only recolors the border. Same
    /// accent-layer vocabulary as OverrideChrome's active rows.
    /// Negative padding keeps the layout footprint unchanged.
    private var recordButton: some View {
        Button(action: toggle) {
            Text(label)
                .frame(minWidth: 110)
                .monospaced()
        }
        .buttonStyle(.bordered)
        .tint(buttonTint)
        .background {
            if recording {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.08))
                    .padding(-4)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if recording {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        Color.accentColor.opacity(0.4),
                        lineWidth: 1.5
                    )
                    .padding(-4)
                    .allowsHitTesting(false)
            }
        }
        .help(Self.recordHelp)
    }

    @MainActor private static let recordHelp = L(
        "key_recorder.help",
        "A shortcut is one key plus any of "
            + "⌃ Control, ⌥ Option, ⇧ Shift, "
            + "and ⌘ Command — it locks in when "
            + "you release the keys. For more "
            + "shortcut layers, add Modes."
    )

    // MARK: - Rejection UI (#34)

    /// The stored rejection re-validated against live
    /// bindings on every render — the holder may have been
    /// cleared or deleted since it was raised, and a stale
    /// "Assigned to…" row must follow it out.
    private var liveRejection: RecorderRejection? {
        guard let rejection, let preflight else { return nil }
        return preflight(rejection.combo)
    }

    private func rejectionRow(
        _ rejection: RecorderRejection
    ) -> some View {
        HStack(spacing: 6) {
            Text(
                L(
                    "key_recorder.assigned_to",
                    "Assigned to \u{201C}%1$@\u{201D}",
                    rejection.holder
                )
            )
            .foregroundStyle(.red)
            Button(L("key_recorder.steal", "Steal")) {
                self.rejection = nil
                rejection.steal()
            }
            Button(L("key_recorder.go_to", "Go to")) {
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
            return preview.isEmpty
                ? L("key_recorder.press_keys", "Press keys…")
                : preview
        }
        guard !combo.isEmpty else {
            return L("key_recorder.record", "Record")
        }
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
        preview = ""
        hint = nil
        takenBy = nil
        // Claiming tears down whichever field was recording
        // before — synchronously, so two keyDown monitors
        // never coexist (#33). Captures reach the heap-backed
        // State storage either way (via the class reference
        // and the Binding); the strong recorder capture is
        // load-bearing — it keeps the recorder alive to run
        // stop() even if the view's state died first.
        let previewBinding = $preview
        let hintBinding = $hint
        let takenBinding = $takenBy
        coordinator.claim(fieldID) { [recorder] in
            recorder.stop()
            previewBinding.wrappedValue = ""
            hintBinding.wrappedValue = nil
            takenBinding.wrappedValue = nil
        }
        recorder.start(
            preview: { display, combo in
                preview = display
                takenBy = combo.flatMap {
                    preflight?($0)?.holder
                }
            },
            hint: { hint = $0 },
            finish: { outcome in
                finish(outcome)
            }
        )
    }

    private func finish(_ outcome: ChordRecorder.Outcome) {
        preview = ""
        hint = nil
        takenBy = nil
        coordinator.release(fieldID)
        switch outcome {
        case .chord(let combo):
            commit(combo)
        case .clickAway:
            cancelledByClick = Date()
        case .cancelled:
            break
        }
    }

    private func stop() {
        recorder.stop()
        preview = ""
        hint = nil
        takenBy = nil
        coordinator.release(fieldID)
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
