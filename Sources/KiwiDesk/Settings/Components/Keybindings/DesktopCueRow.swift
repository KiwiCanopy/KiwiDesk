import KiwiDeskCore
import SwiftUI

/// The Desktop switch cue's switch (#2142), the macOS Desktops
/// section's first row (#2655): app-wide (#1741), written at once
/// like the layout plate's switch, and greyed only where
/// `init.lua` owns the config — its own gate, never the shortcut
/// rows'.
struct DesktopCueRow: View {
    @ObservedObject var model: SettingsModel

    private var reason: ShortcutsGates.InertReason? {
        ShortcutsGates(config: model.config, guiManaged: model.guiManaged)
            .inertReason(for: .shortcuts(.desktopCue))
    }

    var body: some View {
        // Starts at the rows' text, as the layout cue does (#2670).
        VStack(alignment: .leading, spacing: 4) { content }
            .padding(
                .leading,
                ShortcutSettingRow<EmptyView, EmptyView>.captionIndent
            )
    }

    @ViewBuilder private var content: some View {
        let luaOwned = reason == .appWideLuaOwned
        ToggleRow(
            label: SettingsCatalog.shortcuts.desktopCue.text,
            isOn: Binding(
                get: { model.appWide.desktopCue },
                set: { on in model.setAppWide { $0.desktopCue = on } }
            ),
            help: L(
                "desktops.cue.help",
                "KiwiDesk switches Desktops without macOS's slide "
                    + "animation, so for a moment it shows the "
                    + "Desktop's number on the screen that switched, "
                    + "with a dot for each Desktop on that screen and "
                    + "the profile it loaded, if any."
            ),
            disabled: luaOwned
        )
        .searchAnchored(SettingsCatalog.shortcuts.desktopCue)
        if luaOwned {
            Text(GeneralGateHelp.sentence(for: .luaOwned))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, ToggleRow.captionIndent)
        }
    }
}
