import KiwiDeskCore
import SwiftUI

/// The Desktop switch cue's switch (#2142): app-wide (#1741),
/// written at once like General's app-wide rows, and greyed only
/// where `init.lua` owns the config — its own gate, never the
/// binding rows'.
extension DesktopsGroup {
    @ViewBuilder var switchCueRow: some View {
        let reason = cueGates.inertReason(for: .profiles(.desktopCue))
        ToggleRow(
            label: SettingsCatalog.profiles.desktops.children
                .switchCue.text,
            isOn: Binding(
                get: { model.appWide.desktopCue },
                set: { on in model.setAppWide { $0.desktopCue = on } }
            ),
            help: L(
                "desktops.cue.help",
                "KiwiDesk switches Desktops without the slide, so "
                    + "it shows the number of the Desktop it "
                    + "switched to on that screen for a moment, "
                    + "with a dot for each Desktop there and the "
                    + "profile it loaded, if any."
            ),
            disabled: reason != nil
        )
        .searchAnchored(SettingsCatalog.profiles.desktops.children.switchCue)
        if let reason {
            Text(ProfilesGateHelp.sentence(for: reason))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, ToggleRow.captionIndent)
        }
    }

    private var cueGates: ProfilesGates {
        ProfilesGates(
            editingStoredProfile: model.editingStoredProfile,
            connectedScreens: model.displays.count,
            guiManaged: model.guiManaged,
            sidecarExists: model.sidecarExists
        )
    }
}
