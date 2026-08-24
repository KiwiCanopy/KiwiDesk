import AppKit
import KiwiDeskCore
import SwiftUI

/// The right-hand column of every keybinding row: a recorder
/// that captures a chord into a canonical combo string, with a
/// conflict indicator and a clear button.
///
/// Recording snaps in on key-down (`ChordRecorder`, #212):
/// the field live-previews the held modifiers, and the first
/// non-modifier key locks the combo instantly — correction is
/// re-recording, one click.
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
    /// What VoiceOver calls the field — the command it binds.
    /// The visible text is the COMBO, i.e. its value, so without
    /// this every row announced its value as its name (#812).
    let name: String
    let combo: String
    /// Conflict tooltip; nil when the combo is unique + valid.
    var conflict: String?
    /// KiwiDesk-collision check run before committing; nil
    /// commits unconditionally (no other rows to collide
    /// with).
    var preflight: ((String) -> RecorderRejection?)? = nil
    /// Commits the combo; returns the live-apply feedback to
    /// flash under the field (#123), or nil when the edit
    /// stays staged (stored-profile target).
    let onRecord: (String) -> LiveApplyFeedback?
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
    @State private var flashing = false
    /// The conflict popover (owner 2026-08-10) — internal, its
    /// view lives in `KeyRecorderField+Conflict.swift`.
    @State var conflictPopoverShown = false
    /// Transient live-apply caption (#123): "Active now" (or
    /// the system-denied branch), auto-fading after ~1.5 s.
    @State private var liveFeedback: LiveApplyFeedback?

    private var recording: Bool {
        coordinator.active == fieldID
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                conflictBadge
                recordButton
                clearButton
            }
            if let rejection = liveRejection {
                rejectionRow(rejection)
            }
            if let liveFeedback {
                LiveApplyCaption(feedback: liveFeedback)
            }
        }
        .onChange(of: liveFeedback) { _, feedback in
            guard let feedback else { return }
            Task { @MainActor in
                try? await Task.sleep(
                    nanoseconds: 1_500_000_000
                )
                // A newer recording restarted the timer —
                // only the latest feedback clears itself.
                if liveFeedback == feedback {
                    withAnimation { liveFeedback = nil }
                }
            }
        }
        .onChange(of: coordinator.generation) { _, _ in
            // The edited mode/target changed — any pending
            // rejection or feedback captured stale bindings.
            rejection = nil
            liveFeedback = nil
            recorder.stop()
            preview = ""
        }
        .onChange(of: liveRejection == nil) { _, clear in
            // The latch follows the live check out: once the
            // conflict is fixed anywhere, a later collision on
            // the same combo must not resurrect this row.
            if clear { rejection = nil }
        }
        .onDisappear(perform: stop)
    }

    /// The fixed width of a trailing-cluster icon slot (#264).
    /// `exclamationmark.triangle` / `xmark.circle` plus the
    /// hover chip's padding fit inside 20 pt. (Deliberately not
    /// NavRow's 18 pt glyph slot — these icons carry a hover
    /// chip, that glyph doesn't.)
    static let iconSlotWidth: CGFloat = 20

    /// A fixed-width icon slot: `Color.clear` reserves the width
    /// even when `content` is empty, so the record button's
    /// leading edge holds its x across unbound/bound/conflict
    /// states instead of the varying cluster width letting the
    /// row's `Spacer` push it (#264). The glyph draws in an
    /// overlay above the reserved base. Internal: the conflict
    /// badge consumes it from its own file.
    func iconSlot<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        Color.clear
            .frame(width: Self.iconSlotWidth)
            .overlay { content() }
    }

    private var clearButton: some View {
        iconSlot {
            if !combo.isEmpty && !recording {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(SettingsTheme.ink2)
                .iconButtonAffordance(
                    L(
                        "key_recorder.clear",
                        "Clear shortcut"
                    )
                )
            }
        }
    }

    /// Extracted from `body` — the full modifier chain in one
    /// expression blew the type-checker's budget on CI. The
    /// input-well chrome lives in `RecorderButtonChrome`
    /// (same accent-layer vocabulary as OverrideChrome's
    /// active rows).
    private var recordButton: some View {
        Button(action: toggle) {
            Text(label)
                .frame(minWidth: 110)
                .monospaced()
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        // Both halves: a field resolving its own tint owes the
        // same pair `neutralButtonLabel()` argues for, not half.
        .tint(buttonTint)
        .foregroundStyle(buttonTint)
        .modifier(RecorderButtonChrome(recording: recording))
        .help(Self.recordHelp)
        .accessibilityLabel(name)
        // The combo; "Record" / "Press keys…" are states.
        .accessibilityValue(label)
    }

    // A meaning change replaced the old `help` key (#212 —
    // the recorder no longer locks on release): per
    // docs/translating.md a changed English text gets a NEW
    // key, never a rename. The closing sentence changed again
    // with the layers rename — the key is right for the same
    // spot, so it keeps its name and `scripts/drop-key`
    // retires the eleven translations of the old wording.
    @MainActor private static let recordHelp = L(
        "key_recorder.help_press",
        "A shortcut is one key plus any of "
            + "⌃ Control, ⌥ Option, ⇧ Shift, "
            + "and ⌘ Command — it locks in the "
            + "moment you press the key. Add a layer "
            + "to give one key a second meaning."
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
        KeyRecorderRejectionRow(
            rejection: rejection,
            onSteal: {
                self.rejection = nil
                rejection.steal()
            },
            onGoTo: {
                self.rejection = nil
                coordinator.scrollTarget =
                    rejection.holderRowID
            },
            onDismiss: { self.rejection = nil }
        )
    }

    /// Ink unless the chord was rejected. `.bordered` paints its
    /// label from the tint, so any other resting value is text in
    /// the accent — the defect `neutralButtonLabel()` removes
    /// everywhere else, and this field is not exempt from it.
    ///
    /// Red survives for the same reason a destructive button's
    /// does: the flash IS the rejection, and there is nothing
    /// else on screen saying so.
    ///
    /// **Recording used to return the accent and no longer
    /// does.** The justification was that the tint fed the
    /// chrome's fill, which is false — `KeyRecorderChrome` fills
    /// and strokes from `SettingsTheme.accent` directly and never
    /// reads the tint. So on that arm the tint's only remaining
    /// job was painting "Press keys…" and the live combo preview
    /// in the accent: text naming a value. The recording signal
    /// is unaffected, because the chrome draws it independently.
    private var buttonTint: Color {
        flashing ? SettingsTheme.danger : SettingsTheme.ink
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
        // Claiming tears down whichever field was recording
        // before — synchronously, so two keyDown monitors
        // never coexist (#33). Captures reach the heap-backed
        // State storage either way (via the class reference
        // and the Binding); the strong recorder capture is
        // load-bearing — it keeps the recorder alive to run
        // stop() even if the view's state died first.
        let previewBinding = $preview
        coordinator.claim(fieldID) { [recorder] in
            recorder.stop()
            previewBinding.wrappedValue = ""
        }
        recorder.start(
            preview: { display in
                preview = display
            },
            finish: { outcome in
                finish(outcome)
            }
        )
    }

    private func finish(_ outcome: ChordRecorder.Outcome) {
        preview = ""
        // Release BEFORE commit (#213): release resumes the live
        // hotkeys, so the subsequent live-apply reads a truthful
        // `activationFailures` and its "Active now" / system-
        // denied caption is honest. Committing while still armed
        // would leave the table unregistered and every recording
        // would falsely report success.
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
        liveFeedback = onRecord(string)
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
