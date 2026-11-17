import AppKit
import KiwiDeskCore
import SwiftUI

/// A gesture row's keys (#3199 ▸ Ruling): the shortcut recorder's
/// well, recording modifiers alone — the largest set held commits
/// when every key is released. A gesture that may hold no keys
/// (`allowsNone`) reads "None" while empty and keeps its × to clear
/// back to it; any other reads "Record". A chord `refuse` answers
/// shows its sentence under the well, is announced and writes
/// nothing, which is where a clash reads. Needs the section's
/// `RecorderCoordinator`.
struct GestureChordRecorder: View {
    /// VoiceOver's name for the well.
    let name: String
    let chord: ScrollChord
    let allowsNone: Bool
    /// Core's verdict on a recorded chord; nil accepts it.
    let refuse: (ScrollChord) -> String?
    let onRecord: (ScrollChord) -> Void
    /// Arms on arrival — a new row's keys (#3199 ▸ Ruling).
    var armsOnAppear = false

    @EnvironmentObject private var coordinator: RecorderCoordinator
    @Environment(\.hyperKeyIsOff) private var hyperKeyIsOff
    @State private var fieldID = UUID()
    @State private var recorder = ChordRecorder()
    @State private var preview = ""
    @State private var cancelledByClick: Date?
    @State private var refusal: String?
    @State private var flashing = false

    private var recording: Bool { coordinator.active == fieldID }

    /// The empty recorder's width, drawn hidden: the well and the ×
    /// slot, as `body` lays them out, so a row holding no recorder
    /// lines its reach up with the gesture rows'.
    static var footprint: some View {
        HStack(spacing: 6) {
            KeyRecorderField.recordWell(" ") {}
            Color.clear.frame(width: KeyRecorderField.iconSlotWidth)
        }
        .hidden()
        .accessibilityHidden(true)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                recordButton
                clearButton
            }
            if let refusal {
                Text(refusal)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            } else if hyperDormant {
                Text(Self.dormantCaption)
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
        .onAppear { if armsOnAppear { start() } }
        .onDisappear(perform: stop)
    }

    private var recordButton: some View {
        KeyRecorderField.recordWell(label, action: toggle)
            .tint(buttonTint)
            .foregroundStyle(buttonTint)
            .modifier(
                RecorderButtonChrome(recording: recording, flashing: flashing)
            )
            // Dim, never disable: re-recording is how a row leaves
            // Hyper, as a key row's well (#1870, #3407).
            .opacity(hyperDormant ? 0.55 : 1)
            .help(Self.recordHelp)
            .accessibilityLabel(name)
            .accessibilityValue(SidedChordWords.label(label))
            .accessibilityHint(hyperDormant ? Self.dormantCaption : "")
    }

    private var clearButton: some View {
        Color.clear
            .frame(width: KeyRecorderField.iconSlotWidth)
            .overlay {
                if allowsNone && !chord.isEmpty && !recording {
                    Button {
                        refusal = nil
                        commit([])
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(SettingsTheme.ink2)
                    .iconButtonAffordance(Self.clearHelp)
                }
            }
    }

    /// A Hyper chord while no Hyper key is set: it cannot fire.
    private var hyperDormant: Bool {
        hyperKeyIsOff && !recording && chord.contains(.hyper)
    }

    static var dormantCaption: String {
        L(
            "shortcuts.gestures.hyper_dormant",
            "Hyper is off, so this gesture doesn't work."
        )
    }

    private var buttonTint: Color {
        flashing ? SettingsTheme.danger : SettingsTheme.ink
    }

    var label: String {
        Self.label(
            chord: chord,
            allowsNone: allowsNone,
            recording: recording,
            preview: preview
        )
    }

    /// What the well draws: the held keys while recording, the chord,
    /// else "None" or "Record" by whether no keys is a binding.
    static func label(
        chord: ScrollChord,
        allowsNone: Bool,
        recording: Bool,
        preview: String
    ) -> String {
        if recording {
            return preview.isEmpty
                ? L("shortcuts.gestures.scroll.hold", "Hold keys…")
                : preview
        }
        if !chord.isEmpty { return ScrollChordGlyphs.text(chord) }
        return allowsNone ? noneLabel : L("key_recorder.record", "Record")
    }

    static var noneLabel: String {
        L("shortcuts.gestures.keys.none", "None")
    }

    static var recordHelp: String {
        L(
            "shortcuts.gestures.keys.help",
            "Click, then hold the keys this gesture takes and let go."
        )
    }

    static var clearHelp: String {
        L("shortcuts.gestures.keys.clear", "Take no keys")
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
            hyper: !hyperKeyIsOff,
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
        guard recorded != chord else { return }
        if recorded.isEmpty && !allowsNone { return }
        if let found = refuse(recorded) {
            refusal = found
            flash()
            announce(found)
            return
        }
        onRecord(recorded)
    }

    /// A refusal changes nothing the well shows, so VoiceOver is
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
