import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Gaps & Borders ▸ Sticky windows (#414): the
/// on-window mark's toggle. Sits below the focus border — the
/// mark is its overlay sibling.
///
/// Coverage guard (GUI-only, #171 grey-don't-hide): with the
/// Space Bar off, this is the ONLY sticky mark, so the
/// toggle renders forced ON and disabled — sticky state must
/// never be invisible from the GUI. The stored value is not
/// touched, and Lua stays free to set any combination
/// (`sticky.set_mark`, the dim_factor precedent). The
/// guard keys on the Space Bar (never the per-layout App Bar);
/// `SpaceBarStyle.enabled` is deliberately a single global
/// bool, so this is one `.disabled`, no per-space cases.
struct StickyMarkEditor: View {
    @ObservedObject var model: SettingsModel

    private var spaceBarOn: Bool {
        model.config.settings.spaceBarStyle.enabled
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.gapsAndBorders.stickyWindows,
            caption: L(
                "sticky.caption",
                "Sticky windows stay visible on every "
                    + "space (Toggle sticky, in Shortcuts)."
            )
        ) {
            ToggleRow(
                label: L(
                    "sticky.mark",
                    "Show mark on sticky windows"
                ),
                isOn: spaceBarOn
                    ? $model.config.settings.stickyStyle
                        .mark
                    : .constant(true),
                help: L(
                    "sticky.mark.help",
                    "A sticky window can look identical to a "
                        + "normal one, so KiwiDesk draws a small "
                        + "mark in its top-right corner. The "
                        + "Space Bar shows its own sticky badge "
                        + "either way."
                )
            )
            .disabled(!spaceBarOn)
            if !spaceBarOn {
                // A live state-dependent fact → caption, not
                // the `?` popover (#94).
                CrossReferenceRow(
                    prose: L(
                        "sticky.mark.forced",
                        "On — the Space Bar is off, so this "
                            + "is the only sticky mark."
                    ),
                    linkTitle: L(
                        "sticky.mark.forced_link",
                        "Space Bar"
                    ),
                    destination: .bars
                )
            }
        }
    }
}
