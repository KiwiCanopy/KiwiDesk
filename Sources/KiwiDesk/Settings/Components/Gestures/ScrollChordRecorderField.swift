import KiwiDeskCore
import SwiftUI

/// A scroll gesture's modifier recorder (#1656): the shortcut
/// recorder's field and inline ×, recording modifiers alone — the
/// largest set held commits when every key is released. A refused
/// chord shows its reason under the field and writes nothing; × is
/// off. Needs the section's `RecorderCoordinator`, and never reads
/// the layer name: a gesture chord belongs to no layer.
struct ScrollChordRecorderField: View {
    /// VoiceOver's name for the field.
    let name: String
    @Binding var chord: ScrollChord
    /// The other gesture's chord, which this one may not take.
    let other: ScrollChord

    @EnvironmentObject private var coordinator: RecorderCoordinator
    @State private var fieldID = UUID()
    @State private var recorder = ChordRecorder()
    @State private var preview = ""
    @State private var cancelledByClick: Date?
    @State private var refusal: ScrollChordRefusal?
    @State private var flashing = false

    private var recording: Bool { coordinator.active == fieldID }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                recordButton
                clearButton
            }
            if let refusal {
                Text(Self.caption(refusal))
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
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
                .frame(minWidth: 72)
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
                    .iconButtonAffordance(
                        L(
                            "shortcuts.gestures.scroll.clear",
                            "Turn this gesture off"
                        )
                    )
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

    @MainActor private static var recordHelp: String {
        L(
            "shortcuts.gestures.scroll.help",
            "Hold two or more of ⌃ Control, ⌥ Option, ⇧ Shift and "
                + "⌘ Command, then let go — the keys you held "
                + "together are recorded."
        )
    }

    /// The sentence under the field for a refused chord.
    @MainActor static func caption(_ refusal: ScrollChordRefusal) -> String {
        switch refusal {
        case .singleModifier:
            return L(
                "shortcuts.gestures.scroll.refused_single",
                "Hold two or more keys: ⌃ + scroll is macOS Zoom's, "
                    + "and ⌘ or ⌥ + scroll mean something in many "
                    + "apps."
            )
        case .otherGesture:
            return L(
                "shortcuts.gestures.scroll.refused_other",
                "These keys are kept for stepping between Spaces."
            )
        }
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
        case .cancelled, .chord:
            break
        }
    }

    private func stop() {
        recorder.stop()
        preview = ""
        coordinator.release(fieldID)
    }

    private func commit(_ recorded: ScrollChord) {
        if let found = ScrollChordRefusal.of(recorded, other: other) {
            refusal = found
            flash()
            return
        }
        chord = recorded
    }

    private func flash() {
        flashing = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            flashing = false
        }
    }
}
