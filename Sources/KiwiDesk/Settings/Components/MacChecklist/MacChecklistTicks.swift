import KiwiDeskCore
import SwiftUI

/// One tick per essential in the rows' own vocabulary, off the one
/// `SettingsModel.macChecklistVerdicts` list the count reads (#1365):
/// the Home card's preview and Simple's checklist header (#3290).
/// Hidden from VoiceOver; the count beside it speaks.
struct MacChecklistTicks: View {
    let verdicts: [Bool]
    let font: Font

    @MainActor init(_ model: SettingsModel, font: Font) {
        verdicts = model.macChecklistVerdicts
        self.font = font
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(verdicts.enumerated()), id: \.offset) {
                tick($0.element)
            }
        }
        .accessibilityHidden(true)
    }

    private func tick(_ done: Bool) -> some View {
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
            .font(font)
            .foregroundStyle(
                done ? SettingsTheme.groupHeading : SettingsTheme.ink3
            )
    }
}
