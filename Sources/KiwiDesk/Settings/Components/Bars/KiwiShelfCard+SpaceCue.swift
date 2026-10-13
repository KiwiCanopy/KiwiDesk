import KiwiDeskCore
import SwiftUI

/// The Space switch plate's switch (#2228): app-wide (#1741),
/// written at once like the Desktop cue's row, and greyed only
/// where `init.lua` owns the config, as `BarsGates` answers it. It
/// sits under the Space Bar switch and is never greyed by it: the
/// plate is for a screen the bar does not draw on.
extension KiwiShelfCard {
    @ViewBuilder var spaceCueRow: some View {
        let reason = BarsGates(
            settings: model.config.settings,
            guiManaged: model.guiManaged
        ).inertReason(for: .spaceBar(.spaceCue))
        ToggleRow(
            label: SettingsCatalog.bars.spaceCue.text,
            isOn: Binding(
                get: { model.appWide.spaceCue },
                set: { on in model.setAppWide { $0.spaceCue = on } }
            ),
            help: L(
                "space_bar.cue.help",
                "For a moment, shows the Space you arrived on and "
                    + "its layout. Only on a screen with no Space "
                    + "Bar, and never over a full-screen app or a "
                    + "presentation."
            ),
            disabled: reason != nil
        )
        .searchAnchored(SettingsCatalog.bars.spaceCue)
        if let reason {
            Text(BarsGateHelp.sentence(for: reason))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, ToggleRow.captionIndent)
        }
    }
}
