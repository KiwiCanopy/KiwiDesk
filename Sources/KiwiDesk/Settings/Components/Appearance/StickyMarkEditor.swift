import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Appearance ▸ Sticky windows (#414): the
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
            SettingsCatalog.appearance.stickyWindows,
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
            Divider()
            markColors
        }
    }

    /// The sticky/floating mark tints (#429): the sticky color
    /// paints the on-window mark glyph and the Space Bar sticky
    /// badge; the floating color paints the Space Bar floating
    /// badge. Both default to Automatic (the adaptive system
    /// label color) — colors gate nothing, so they group as a
    /// small pair for scannability (AGENTS §2.7 carve-out).
    @ViewBuilder private var markColors: some View {
        Text(L("sticky.mark_color", "Mark color"))
            .font(.subheadline.weight(.semibold))
        HexColorField(
            label: L("sticky.color", "Sticky"),
            a11yLabel: L(
                "sticky.color.a11y",
                "Sticky window mark color"
            ),
            automatic: true,
            hex: $model.config.settings.stickyStyle.color
        )
        // The floating mark's ONLY surface is the Space Bar
        // badge (`KiwiCore+SpaceBar`), so this tints nothing
        // while the bar is off — greyed, not hidden (#171).
        // The sticky color above is deliberately NOT gated: it
        // also paints the on-window mark, so it stays live.
        HexColorField(
            label: L("floating.color", "Floating"),
            a11yLabel: L(
                "floating.color.a11y",
                "Floating window mark color"
            ),
            automatic: true,
            hex: $model.config.settings.floatingStyle.color
        )
        .modifier(
            GreyOut(
                active: !spaceBarOn,
                help: L(
                    "floating.color.space_bar_only",
                    "The floating mark is drawn only in the "
                        + "Space Bar, which is off."
                )
            )
        )
    }
}
