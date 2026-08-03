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
                    prose: Self.forcedProse,
                    linkTitle: L(
                        "sticky.mark.forced_link",
                        "Space Bar"
                    ),
                    destination: .bars
                )
            }
        }
    }

    /// The sentence NAMES the Space Bar, so the link is that
    /// mention rather than a second copy trailing the full stop
    /// — which is what the row's old fixed-order `HStack` left
    /// on screen. Hoisted out of `body` for the type-checker:
    /// a `+`-concatenated literal inside a conditional inside a
    /// `ViewBuilder` is the shape that compiles here and dies on
    /// the slower CI runner (gui.md, SwiftUI traps).
    ///
    /// Internal and `static` so `CrossReferenceRowSlotTests` can
    /// assert the string itself rather than scanning for the
    /// slot's name in source.
    static var forcedProse: String {
        L(
            "sticky.mark.forced",
            "On — the %1$@ is off, so this is the only sticky "
                + "mark.",
            CrossReferenceRow.linkSlot
        )
    }
}
