import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Appearance ▸ Sticky windows (#414): the
/// on-window mark's toggle. Sits below the focus border — the
/// mark is its overlay sibling.
///
/// Coverage guard (GUI-only, #171 grey-don't-hide): with the
/// Space Bar off, the mark is the ONLY sticky indicator, so the
/// toggle renders forced ON and disabled — sticky state must
/// never be invisible from the GUI. The stored value is not
/// touched, and Lua stays free to set any combination
/// (`sticky.set_indicator`, the dim_factor precedent). The
/// guard keys on the Space Bar (never the per-layout App Bar);
/// `SpaceBarStyle.enabled` is deliberately a single global
/// bool, so this is one `.disabled`, no per-space cases.
struct StickyIndicatorEditor: View {
    @ObservedObject var model: SettingsModel

    private var spaceBarOn: Bool {
        model.config.settings.spaceBarStyle.enabled
    }

    var body: some View {
        SettingsSection(
            L("sticky.title", "Sticky windows"),
            caption: L(
                "sticky.caption",
                "Sticky windows stay visible on every "
                    + "space (Toggle sticky, in Shortcuts)."
            )
        ) {
            ToggleRow(
                label: L(
                    "sticky.indicator",
                    "Show mark on sticky windows"
                ),
                isOn: spaceBarOn
                    ? $model.config.settings.stickyStyle
                        .indicator
                    : .constant(true),
                help: L(
                    "sticky.indicator.help",
                    "A sticky window can look identical to a "
                        + "normal one, so KiwiDesk marks it "
                        + "with a small badge in its top-right "
                        + "corner. The Space Bar shows its own "
                        + "sticky badge either way."
                )
            )
            .disabled(!spaceBarOn)
            if !spaceBarOn {
                // A live state-dependent fact → caption, not
                // the `?` popover (#94).
                CrossReferenceRow(
                    prose: L(
                        "sticky.indicator.forced",
                        "On — the Space Bar is off, so this "
                            + "is the only sticky indicator."
                    ),
                    linkTitle: L(
                        "sticky.indicator.forced_link",
                        "Space Bar"
                    ),
                    destination: .bars
                )
            }
        }
    }
}
