import AppKit
import KiwiDeskCore
import SwiftUI

/// Keybinding recorder capturing shortcuts into canonical combo strings (#212,
/// #33, #34).
struct KeyRecorderField: View {
    let name: String
    let combo: String
    var conflict: String?
    var preflight: ((String) -> RecorderRejection?)? = nil
    let onRecord: (String) -> LiveApplyFeedback?
    let onClear: () -> Void

    @EnvironmentObject private var coordinator: RecorderCoordinator
    @Environment(\.accessibilityReduceMotion)
    var reduceMotion
    @State private var fieldID = UUID()
    @State private var recorder = ChordRecorder()
    @State private var preview = ""
    @State private var cancelledByClick: Date?
    @State private var rejection: RecorderRejection?
    @State private var flashing = false
    @State var conflictPopoverShown = false
    @State var liveFeedback: LiveApplyFeedback?

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
            scheduleFeedbackFade(feedback)
        }
        .onChange(of: coordinator.generation) { _, _ in
            rejection = nil
            liveFeedback = nil
            recorder.stop()
            preview = ""
        }
        .onChange(of: liveRejection == nil) { _, clear in
            if clear { rejection = nil }
        }
        .onDisappear(perform: stop)
    }

    /// Fixed width for trailing action icon slots (#264).
    static let iconSlotWidth: CGFloat = 20

    /// Fixed-width slot reserving space across icon states (#264).
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

    private var recordButton: some View {
        Button(action: toggle) {
            Text(label)
                .frame(minWidth: 110)
                .monospaced()
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(buttonTint)
        .foregroundStyle(buttonTint)
        .modifier(RecorderButtonChrome(recording: recording))
        .help(Self.recordHelp)
        .accessibilityLabel(name)
        .accessibilityValue(label)
    }

    @MainActor private static let recordHelp = L(
        "key_recorder.help_press",
        "A shortcut is one key plus any of "
            + "⌃ Control, ⌥ Option, ⇧ Shift, "
            + "and ⌘ Command — it locks in the "
            + "moment you press the key. Add a layer "
            + "to give one key a second meaning."
    )

    // MARK: - Rejection UI (#34)

    /// Live re-validation of pending rejection (#34).
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
        // Release coordinator before committing hotkey (#213).
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

    /// Validates preflight and commits recorded combo string (#34).
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
