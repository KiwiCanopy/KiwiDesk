import AppKit
import KiwiDeskCore
import SwiftUI

/// The Hyper key's recorder (#1870): records ONE physical key,
/// sided, in `ChordRecorder`'s `.sourceKey` mode. A key that types
/// text sets `refused` and is announced; the card draws the reason
/// across its row, since a caption here would widen the trailing
/// column. × is off. Needs the section's `RecorderCoordinator`.
struct HyperKeyField: View {
    @Binding var key: HyperSourceKey?
    /// The last press typed text; cleared by the next recording, ×
    /// and a section or profile switch.
    @Binding var refused: Bool
    let disabled: Bool
    /// The row's focus destination for the recorder (#816).
    var focus: FocusState<Bool>.Binding

    @EnvironmentObject private var coordinator: RecorderCoordinator
    @State private var fieldID = UUID()
    @State private var recorder = ChordRecorder()
    @State private var cancelledByClick: Date?
    @State private var flashing = false

    private var recording: Bool { coordinator.active == fieldID }

    var body: some View {
        HStack(spacing: 6) {
            recordButton
            clearButton
        }
        .disabled(disabled)
        .onChange(of: coordinator.generation) { _, _ in
            refused = false
            recorder.stop()
        }
        .onDisappear {
            refused = false
            stop()
        }
    }

    private var recordButton: some View {
        Button(action: toggle) {
            Text(label)
                .frame(minWidth: 110)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(buttonTint)
        .foregroundStyle(buttonTint)
        .modifier(
            RecorderButtonChrome(recording: recording, flashing: flashing)
        )
        .accessibilityLabel(HyperKeyWords.useAs)
        .accessibilityValue(spokenValue)
        .focused(focus)
    }

    private var clearButton: some View {
        Color.clear
            .frame(width: KeyRecorderField.iconSlotWidth)
            .overlay {
                if key != nil && !recording {
                    Button {
                        refused = false
                        key = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(SettingsTheme.ink2)
                    .iconButtonAffordance(HyperKeyWords.clear)
                }
            }
    }

    private var buttonTint: Color {
        flashing ? SettingsTheme.danger : SettingsTheme.ink
    }

    private var label: String {
        if recording { return HyperKeyWords.pressKey }
        return key.map(HyperKeyWords.name) ?? HyperKeyWords.record
    }

    /// Drawn "Record key" when empty, which is the button's
    /// action; spoken as the state, off.
    private var spokenValue: String {
        guard !recording, key == nil else { return label }
        return SettingsValueReadout.onOff(false)
    }

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
        refused = false
        coordinator.claim(fieldID) { [recorder] in recorder.stop() }
        recorder.start(
            mode: .sourceKey,
            preview: { _ in },
            finish: { finish($0) }
        )
    }

    private func finish(_ outcome: ChordRecorder.Outcome) {
        coordinator.release(fieldID)
        switch outcome {
        case .sourceKey(let code):
            commit(code)
        case .clickAway:
            cancelledByClick = Date()
        case .cancelled, .chord, .modifiers:
            break
        }
    }

    private func stop() {
        recorder.stop()
        coordinator.release(fieldID)
    }

    /// While Hyper is on, the key already arrives as F18: pressing
    /// it again keeps the key it is.
    private func commit(_ code: UInt16) {
        guard let recorded = Self.committed(code: code, current: key)
        else {
            refused = true
            flash()
            announce(HyperKeyWords.typesText)
            return
        }
        key = recorded
    }

    /// The key a press records, nil for a key that types. While
    /// Hyper is on the key already arrives as F18, so pressing it
    /// again keeps the key it is.
    static func committed(
        code: UInt16,
        current: HyperSourceKey?
    ) -> HyperSourceKey? {
        guard let recorded = HyperSourceKey(keyCode: code) else {
            return nil
        }
        let trigger = HyperSourceKey.trigger
        return recorded == trigger ? current ?? trigger : recorded
    }

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
