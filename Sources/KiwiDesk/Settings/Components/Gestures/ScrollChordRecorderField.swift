import AppKit
import KiwiDeskCore
import SwiftUI

/// A scroll gesture's modifier recorder (#1656): the shortcut
/// recorder's field and inline ×, recording modifiers alone — the
/// largest set held commits when every key is released. A refused
/// chord shows its reason under the field, is announced, and
/// writes nothing; × is off. The other gesture's chord offers Go
/// to, which reveals that gesture's row (#1519 ruling). Needs the
/// section's
/// `RecorderCoordinator`, and never reads the layer name: a
/// gesture chord belongs to no layer.
struct ScrollChordRecorderField: View {
    /// VoiceOver's name for the field.
    let name: String
    @Binding var chord: ScrollChord
    /// The other gesture's chord, which this one may not take,
    /// and that gesture, which the refusal names.
    let other: ScrollChord
    let otherGesture: ScrollGestures.Consumer
    /// Reveals the other gesture's recorder; the refusal keeps its
    /// caption, so the link keeps the keyboard focus.
    var goToOther: (() -> Void)?

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
                refusalCaption(refusal)
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
        .modifier(RecorderButtonChrome(recording: recording))
        .help(Self.recordHelp)
        .accessibilityLabel(name)
        .accessibilityValue(spokenValue)
    }

    @ViewBuilder
    private func refusalCaption(_ refusal: ScrollChordRefusal) -> some View {
        if case .otherGesture = refusal, let goToOther {
            let (leading, trailing) = CrossReferenceRow.split(
                Self.frame(refusal)
            )
            LinkedCaption(
                leading: leading,
                linkTitle: Self.goTo,
                trailing: trailing,
                navigate: goToOther,
                spokenLink: L(
                    "shortcuts.gestures.scroll.go_to_spoken",
                    "Go to %1$@",
                    ScrollGestureWords.label(
                        otherGesture == .pan ? .pan : .spaceStep
                    )
                ),
                ink: NSColor(SettingsTheme.ink2)
            )
        } else {
            Text(Self.caption(refusal))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @MainActor private static var goTo: String {
        L("shortcuts.gestures.scroll.go_to", "Go to")
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

    /// The sentence under the field for a refused chord, without
    /// its link: as announced, and where no Go to is offered.
    @MainActor static func caption(_ refusal: ScrollChordRefusal) -> String {
        frame(refusal)
            .replacingOccurrences(of: CrossReferenceRow.linkSlot, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// The refusal's sentence; the other gesture's carries the Go
    /// to link at `CrossReferenceRow.linkSlot`.
    @MainActor static func frame(_ refusal: ScrollChordRefusal) -> String {
        switch refusal {
        case .singleModifier:
            return L(
                "shortcuts.gestures.scroll.refused_single",
                "Hold two or more keys. With one key, scrolling is "
                    + "already taken: ⌃ zooms the screen in macOS, "
                    + "and ⇧, ⌥ or ⌘ do something in many apps."
            )
        case .otherGesture(.step):
            return L(
                "shortcuts.gestures.scroll.refused_step",
                "These keys already step between Spaces. %1$@",
                CrossReferenceRow.linkSlot
            )
        case .otherGesture(.pan):
            return L(
                "shortcuts.gestures.scroll.refused_pan",
                "These keys already move focus window by window. %1$@",
                CrossReferenceRow.linkSlot
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
        if let found = ScrollChordRefusal.of(
            recorded,
            other: other,
            heldBy: otherGesture
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
