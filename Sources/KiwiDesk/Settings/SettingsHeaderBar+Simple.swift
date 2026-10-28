import AppKit
import KiwiDeskCore
import SwiftUI

/// Simple's title row (#2737): the edited profile's name, the
/// screen count and what Simple hides, then the switch. No search
/// and no profile selector — every way into Advanced is named.
extension SettingsHeaderBar {
    var simpleTitleRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.editTargetTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(SettingsTheme.ink)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                if let line = SimpleHeaderSubtitle.line(
                    screenCount: model.displays.count,
                    hidden: model.simpleHiddenCounts
                ) {
                    simpleSubtitle(line)
                }
            }
            Spacer(minLength: 12)
            SettingsRootSwitch(model: model)
        }
        .padding(.leading, SettingsHeaderBar.trafficLightInset)
    }

    @ViewBuilder private func simpleSubtitle(_ line: String) -> some View {
        if line.contains(CrossReferenceRow.linkSlot) {
            let (leading, trailing) = CrossReferenceRow.split(line)
            LinkedCaption(
                leading: leading,
                linkTitle: SettingsRootSwitch.advancedTitle,
                trailing: trailing,
                navigate: { model.openAdvanced() },
                pointSize: NSFont.preferredFont(
                    forTextStyle: .subheadline
                ).pointSize
            )
        } else {
            Text(line)
                .font(.subheadline)
                .foregroundStyle(SettingsTheme.ink2)
        }
    }
}
