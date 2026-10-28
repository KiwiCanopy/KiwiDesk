import AppKit
import KiwiDeskCore
import SwiftUI

/// Keybinding recorder capturing shortcuts into canonical combo
/// strings (#212, #33, #34). Requires a `RecorderCoordinator` in
/// the environment — rendering it outside `ShortcutsSection` is a
/// programmer error and will crash.
struct KeyRecorderField: View {
    /// VoiceOver's name for the field — the command it binds. The
    /// visible text is the COMBO, its value, so without this every
    /// row announced its value as its name (#812).
    let name: String
    let combo: String
    /// The conflict's tier AND its sentence, or nil where there
    /// is none (#1126). A `let` with no default on purpose: the
    /// memberwise init then REQUIRES it, so a new mount cannot
    /// render the old chrome by forgetting it.
    let reading: ConflictReading?
    /// KiwiDesk-collision check run before committing; nil commits
    /// unconditionally.
    var preflight: ((String) -> RecorderRejection?)? = nil
    /// Commits the combo into the draft; Save registers it.
    let onRecord: (String) -> Void
    let onClear: () -> Void

    @EnvironmentObject var coordinator: RecorderCoordinator
    @Environment(\.hyperKeyIsOff) private var hyperKeyIsOff
    @Environment(\.recorderSides) private var recorderSides
    @State private var fieldID = UUID()
    @State private var recorder = ChordRecorder()
    @State private var preview = ""
    /// Set when a click-away cancelled recording — the button's own
    /// click lands right after the mouse monitor and must not
    /// immediately restart it.
    @State private var cancelledByClick: Date?
    @State private var rejection: RecorderRejection?
    @State private var flashing = false
    @State var conflictPopoverShown = false

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
            deadCaption
            if let rejection = liveRejection {
                rejectionRow(rejection)
            }
        }
        .onChange(of: coordinator.generation) { _, _ in
            rejection = nil
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
    /// The chord label's least width, so recorders line up; a
    /// sided chord fits it in every catalog
    /// (`ChordGlyphsWidthTests`).
    static let labelMinWidth: CGFloat = 110

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
                .frame(minWidth: Self.labelMinWidth)
                .monospaced()
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(buttonTint)
        .foregroundStyle(buttonTint)
        .modifier(
            RecorderButtonChrome(
                recording: recording,
                dead: isDead,
                flashing: flashing
            )
        )
        // Dim, never disable: re-recording is how a row leaves
        // Hyper (#1870, `keybindingRowStyle`'s rule).
        .opacity(hyperDormant ? 0.55 : 1)
        .help(helpText)
        .accessibilityHint(hint ?? "")
        .accessibilityLabel(name)
        // The cost is announced ONCE, by the badge that precedes
        // this button in the row (#1126) — a second copy here
        // read the same sentence on two adjacent VoiceOver stops.
        .accessibilityValue(SidedChordWords.label(label))
    }

    /// Why the row would not fire as drawn: a Hyper chord with no
    /// key, or a sided chord while sides are not told apart, which
    /// keeps full ink (#2601 ▸ Ruling).
    private var hint: String? {
        Self.rowHint(
            combo: combo,
            sidesOn: recorderSides != nil,
            recording: recording,
            hyperDormant: hyperDormant
        )
    }

    static func rowHint(
        combo: String,
        sidesOn: Bool,
        recording: Bool,
        hyperDormant: Bool
    ) -> String? {
        if hyperDormant { return ShortcutBaseWords.dormantHint }
        if !sidesOn, !recording,
            KeyCombo.parse(combo)?.modifiers.isSided == true
        {
            return ModifierSidesWords.eitherSideHint
        }
        return nil
    }

    /// The hover text: a sided chord in words, then the hint or how
    /// recording works.
    private var helpText: String {
        let spoken = recording ? nil : SidedChordWords.spoken(label)
        return [spoken, hint ?? recordHelp]
            .compactMap { $0 }
            .joined(separator: "\n")
    }

    private var recordHelp: String {
        recorderSides == nil ? Self.recordHelp : Self.recordSidesHelp
    }

    /// The help with sides kept: one frame, so no translation has
    /// to join two sentences (localization.md).
    @MainActor private static var recordSidesHelp: String {
        L(
            "key_recorder.help_press_sides",
            "A shortcut is one key plus any of "
                + "⌃ Control, ⌥ Option, ⇧ Shift, "
                + "and ⌘ Command — it locks in the "
                + "moment you press the key. Add a layer "
                + "to give one key a second meaning. The side "
                + "you press is kept: %1$@ is recorded as %2$@.",
            HyperKeyWords.name(.rightCommand),
            ModifierSidesWords.drawn(.right)
        )
    }

    // Computed: a localized value stored for the life of the
    // process keeps the locale it was first read in (#1311).
    @MainActor private static var recordHelp: String {
        L(
            "key_recorder.help_press",
            "A shortcut is one key plus any of "
                + "⌃ Control, ⌥ Option, ⇧ Shift, "
                + "and ⌘ Command — it locks in the "
                + "moment you press the key. Add a layer "
                + "to give one key a second meaning."
        )
    }

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

    /// A Hyper chord while no Hyper key is set: it cannot fire.
    private var hyperDormant: Bool {
        hyperKeyIsOff && !recording
            && KeyCombo.parse(combo)?.modifiers.contains(.hyper) == true
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
        // Display-only glyph mapping (#23): the stored combo stays
        // the canonical word form, so a parse failure just shows
        // the raw string.
        guard let parsed = KeyCombo.parse(combo) else {
            return combo
        }
        return ChordGlyphs.render(
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
            hyper: !hyperKeyIsOff,
            sides: recorderSides,
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
        case .cancelled, .modifiers, .sourceKey:
            // `.modifiers` is the scroll recorder's and
            // `.sourceKey` the Hyper key's; this field records in
            // `.combo` mode.
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
