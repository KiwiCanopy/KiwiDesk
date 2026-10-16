import KiwiDeskCore
import SwiftUI

/// A lens's Other apps card (#2103 rulings 12, 30, 42a, 52): "Keep
/// focus on these apps" above the two rows it gates, Clear after in
/// half seconds ("Off" at 0) and the Reminder, its default shown as
/// the placeholder. A grey says why inline, outside the dimmed rows.
struct KiwiVisionLensOtherAppsCard: View {
    @ObservedObject var model: SettingsModel
    let lens: VisionLens

    var body: some View {
        SettingsSection(
            KiwiVisionLensWords.otherTitle,
            caption: KiwiVisionLensWords.otherCaption(lens.name),
            help: KiwiVisionLensWords.otherHelp
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ToggleRow(
                    label: KiwiVisionLensWords.keepFocus,
                    isOn: binding(\.keepFocus)
                )
                Text(KiwiVisionLensWords.keepFocusDetail)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .padding(.leading, ToggleRow.captionIndent)
                    .fixedSize(horizontal: false, vertical: true)
                delayRow.disabled(!lens.keepFocus)
                reminderRow.disabled(!remindsAtAll)
                if let reason {
                    KiwiVisionCopy.reason(reason)
                }
            }
        }
    }

    private var remindsAtAll: Bool {
        lens.keepFocus && lens.clearDelay > 0
    }

    /// Why the rows below the switch are greyed, nil while live.
    private var reason: String? {
        if !lens.keepFocus { return KiwiVisionLensWords.needsKeepFocus }
        if lens.clearDelay <= 0 { return KiwiVisionLensWords.needsDelay }
        return nil
    }

    private var delayRow: some View {
        let readout = KiwiVisionLensWords.delay(lens.clearDelay)
        return HStack {
            Text(KiwiVisionLensWords.clearAfter)
                .accessibilityHidden(true)
            Spacer(minLength: 8)
            Text(readout)
                .monospacedDigit()
                .foregroundStyle(SettingsTheme.ink2)
                .accessibilityHidden(true)
            Stepper(
                KiwiVisionLensWords.clearAfter,
                value: binding(\.clearDelay),
                // Ruling 12's band, widened to a Lua value past it,
                // which Core does not cap.
                in: 0...max(5, lens.clearDelay),
                step: 0.5
            )
            .labelsHidden()
            .accessibilityLabel(KiwiVisionLensWords.clearAfter)
            .accessibilityValue(readout)
        }
    }

    private var reminderRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(KiwiVisionLensWords.reminder)
                Text(KiwiVisionLensWords.reminderDetail)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
            }
            .accessibilityHidden(true)
            Spacer(minLength: 8)
            TextField(
                KiwiVisionLensWords.defaultReminder,
                text: Binding(
                    get: { lens.reminder ?? "" },
                    set: { text in
                        let trimmed = text.trimmed
                        model.updateLens(lens.name) {
                            $0.reminder = trimmed.isEmpty ? nil : text
                        }
                    }
                )
            )
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 260)
            .accessibilityLabel(KiwiVisionLensWords.reminder)
        }
    }

    private func binding<V>(_ path: WritableKeyPath<VisionLens, V>)
        -> Binding<V>
    {
        Binding(
            get: { lens[keyPath: path] },
            set: { value in
                model.updateLens(lens.name) { $0[keyPath: path] = value }
            }
        )
    }
}
