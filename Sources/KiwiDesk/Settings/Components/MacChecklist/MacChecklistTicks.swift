import KiwiDeskCore
import SwiftUI

/// One tick per essential in the rows' own vocabulary, off the one
/// `MacChecklistProgress.verdicts` value the count reads (#1365):
/// the Home card's preview and Simple's checklist header (#3290).
/// Hidden from VoiceOver; the count beside it speaks.
struct MacChecklistTicks: View {
    let verdicts: [(setting: MacSetting, done: Bool)]
    let font: Font

    @MainActor init(_ model: SettingsModel, font: Font) {
        verdicts = MacChecklistProgress.verdicts(
            states: model.macChecklistStates,
            ticks: model.macChecklistTicks
        )
        self.font = font
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(verdicts, id: \.setting) { verdict in
                Image(
                    systemName: verdict.done
                        ? "checkmark.circle.fill" : "circle"
                )
                .font(font)
                .foregroundStyle(
                    verdict.done
                        ? SettingsTheme.groupHeading
                        : SettingsTheme.ink3
                )
            }
        }
        .accessibilityHidden(true)
    }
}
