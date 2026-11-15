import KiwiDeskCore
import SwiftUI

/// The Mac Checklist's boxed-in essential (#2756 ▸ Amendment
/// "Mac Checklist item"), in Advanced and Simple alike: the chip,
/// the live sentences and the one button that opens the offer's
/// alert. Shown only while an offer is open; kept as is ticks it,
/// and a yes takes it away.
struct ScreenShiftChecklistRow: View {
    @ObservedObject var model: SettingsModel
    let chipWidth: CGFloat

    var body: some View {
        let state = model.screenShift
        if let offer = state.openOffer {
            let kept = state.answer == .kept
            HStack(
                alignment: .firstTextBaseline,
                spacing: MacSettingRow.rowSpacing
            ) {
                chip(kept: kept)
                ScreenShiftSentences(offer: offer, state: state)
                    .accessibilityValue(spoken(kept: kept))
                Spacer(minLength: 0)
                HelpButton(explanation: ScreenShiftText.help)
                Button(ScreenShiftText.button(offer)) {
                    model.askScreenShift(offer)
                }
                .settingsActionButton()
            }
            .searchAnchored(SettingsCatalog.macChecklist.parkCorners)
        }
    }

    /// Kept as is takes the done mark, so the count and the face
    /// agree; not yet is the empty ring the other rows draw.
    private func chip(kept: Bool) -> some View {
        HStack(spacing: MacSettingRow.chipSpacing) {
            Image(systemName: kept ? "checkmark.circle.fill" : "circle")
            Text(kept ? Self.keptWord : Self.notYetWord)
        }
        .font(MacSettingRow.chipFont)
        .foregroundStyle(
            kept ? SettingsTheme.groupHeading : SettingsTheme.ink3
        )
        .frame(width: chipWidth, alignment: .leading)
        .accessibilityHidden(true)
    }

    private func spoken(kept: Bool) -> String {
        kept
            ? L(
                "mac_checklist.state.kept.spoken",
                "Kept as is, your answer"
            )
            : L(
                "mac_checklist.state.not_yet.offer_spoken",
                "Not yet, for this screen arrangement"
            )
    }

    static var keptWord: String {
        L("mac_checklist.state.kept", "Kept as is")
    }

    static var notYetWord: String {
        L("mac_checklist.state.not_yet", "Not yet")
    }
}
