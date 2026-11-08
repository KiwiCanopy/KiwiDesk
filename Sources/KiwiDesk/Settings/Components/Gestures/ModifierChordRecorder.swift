import AppKit
import KiwiDeskCore
import SwiftUI

/// The modifiers-only recorder the scroll gestures (#1656) and the
/// modifier drags (#2447) share: the shortcut recorder's field and
/// inline ×, recording modifiers alone — the largest set held
/// commits when every key is released. A chord `refuse` answers
/// shows `caption` under the field, is announced, and writes
/// nothing; × is off. Needs the section's `RecorderCoordinator`,
/// and never reads the layer name: a modifier chord belongs to no
/// layer.
struct ModifierChordRecorder<Refusal: Equatable, Caption: View>: View {
    /// VoiceOver's name for the field.
    let name: String
    @Binding var chord: ScrollChord
    /// The field's help, naming the keys it takes.
    let recordHelp: String
    /// The ×'s help, naming what it turns off.
    let clearHelp: String
    /// Core's verdict on a recorded chord; nil accepts it.
    let refuse: (ScrollChord) -> Refusal?
    /// The refusal as VoiceOver announces it.
    let announcement: (Refusal) -> String
    @ViewBuilder let caption: (Refusal) -> Caption

    @EnvironmentObject private var coordinator: RecorderCoordinator
    @State private var fieldID = UUID()
    @State private var recorder = ChordRecorder()
    @State private var preview = ""
    @State private var cancelledByClick: Date?
    @State private var refusal: Refusal?
    @State private var flashing = false

    private var recording: Bool { coordinator.active == fieldID }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                recordButton
                clearButton
            }
            if let refusal {
                caption(refusal)
            }
        }
        .onChange(of: coordinator.generation) { _, _ in
            refusal = nil
            recorder.stop()
            preview = ""
        }
        .onDisappear(perform: stop)
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
        .modifier(
            RecorderButtonChrome(recording: recording, flashing: flashing)
        )
        .help(recordHelp)
        .accessibilityLabel(name)
        .accessibilityValue(spokenValue)
    }

    private var clearButton: some View {
        Color.clear
            .frame(width: KeyRecorderField.iconSlotWidth)
            .overlay {
                if !chord.isEmpty && !recording {
                    Button {
                        refusal = nil
                        chord = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(SettingsTheme.ink2)
                    .iconButtonAffordance(clearHelp)
                }
            }
    }

    private var buttonTint: Color {
        flashing ? SettingsTheme.danger : SettingsTheme.ink
    }

    private var label: String {
        if recording {
            return preview.isEmpty
                ? L("shortcuts.gestures.scroll.hold", "Hold keys…")
                : preview
        }
        return chord.isEmpty
            ? L("key_recorder.record", "Record")
            : ScrollChordGlyphs.text(chord)
    }

    /// Drawn "Record" when empty, which is the button's action;
    /// spoken as the state, off.
    private var spokenValue: String {
        guard !recording, chord.isEmpty else { return label }
        return SettingsValueReadout.onOff(false)
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
        refusal = nil
        preview = ""
        let previewBinding = $preview
        coordinator.claim(fieldID) { [recorder] in
            recorder.stop()
            previewBinding.wrappedValue = ""
        }
        recorder.start(
            mode: .modifiers,
            preview: { preview = $0 },
            finish: { finish($0) }
        )
    }

    private func finish(_ outcome: ChordRecorder.Outcome) {
        preview = ""
        coordinator.release(fieldID)
        switch outcome {
        case .modifiers(let recorded):
            commit(recorded)
        case .clickAway:
            cancelledByClick = Date()
        case .cancelled, .chord, .sourceKey:
            break
        }
    }

    private func stop() {
        recorder.stop()
        preview = ""
        coordinator.release(fieldID)
    }

    private func commit(_ recorded: ScrollChord) {
        if let found = refuse(recorded) {
            refusal = found
            flash()
            announce(announcement(found))
            return
        }
        chord = recorded
    }

    /// A refusal changes nothing the field shows, so VoiceOver is
    /// told why.
    private func announce(_ text: String) {
        guard let window = NSApp.keyWindow else { return }
        NSAccessibility.post(
            element: window,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }

    private func flash() {
        flashing = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            flashing = false
        }
    }
}
