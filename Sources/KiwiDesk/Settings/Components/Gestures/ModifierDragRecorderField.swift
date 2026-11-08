import AppKit
import KiwiDeskCore
import SwiftUI

/// A modifier drag's modifier recorder (#2447): the scroll
/// gestures' modifiers-only recorder, with the drags' own
/// refusals. The largest set held commits when every key is
/// released; a refused chord shows its reason under the field, is
/// announced, and writes nothing; × is off. Needs the section's
/// `RecorderCoordinator`, and never reads the layer name: a drag
/// chord belongs to no layer.
struct ModifierDragRecorderField: View {
    /// VoiceOver's name for the field.
    let name: String
    @Binding var chord: ScrollChord
    /// The other action's chord, which this one may not take.
    let other: ScrollChord
    let otherAction: ModifierDragAction

    @EnvironmentObject private var coordinator: RecorderCoordinator
    @State private var fieldID = UUID()
    @State private var recorder = ChordRecorder()
    @State private var preview = ""
    @State private var cancelledByClick: Date?
    @State private var refusal: ModifierDragRefusal?
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
        .help(Self.recordHelp)
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
                    .iconButtonAffordance(
                        L(
                            "shortcuts.gestures.modifier_drag.clear",
                            "Turn this drag off"
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

    /// Drawn "Record" when empty, which is the button's action;
    /// spoken as the state, off.
    private var spokenValue: String {
        guard !recording, chord.isEmpty else { return label }
        return SettingsValueReadout.onOff(false)
    }

    @MainActor private static var recordHelp: String {
        L(
            "shortcuts.gestures.scroll.help",
            "Hold two or more of ⌃ Control, ⌥ Option, ⇧ Shift, and "
                + "⌘ Command, then let go — the keys you held "
                + "together are recorded."
        )
    }

    /// The sentence under the field for a refused chord.
    @MainActor static func caption(_ refusal: ModifierDragRefusal) -> String {
        switch refusal {
        case .singleModifier:
            return L(
                "shortcuts.gestures.modifier_drag.refused_single",
                "Hold two or more keys. With one key, dragging is "
                    + "already taken: ⌘ moves a window behind others, "
                    + "and ⌥ or ⇧ do something in many apps."
            )
        case .otherAction(.move):
            return L(
                "shortcuts.gestures.modifier_drag.refused_move",
                "These keys already move windows."
            )
        case .otherAction(.resize):
            return L(
                "shortcuts.gestures.modifier_drag.refused_resize",
                "These keys already resize windows."
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
        if let found = ModifierDragRefusal.of(
            recorded,
            other: other,
            heldBy: otherAction
        ) {
            refusal = found
            flash()
            announce(Self.caption(found))
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
