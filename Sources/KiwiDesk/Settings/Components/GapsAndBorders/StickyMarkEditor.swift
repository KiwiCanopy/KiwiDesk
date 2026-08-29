import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Gaps & Borders ▸ Sticky windows (#414): the
/// on-window mark's toggle. Sits below the focus border — the
/// mark is its overlay sibling.
///
/// The toggle stands alone: it carries no gate on the Space Bar.
/// The greying it used to carry asserted a dependency that runs
/// the wrong way — the mark paints on the window, so it is
/// exactly what SURVIVES the bar going off. What the greying was
/// reaching for is timeless rather than live, so it belongs in
/// the row's `?` help (`docs/ui-patterns.md` ▸ Help &
/// cross-references, "A concept goes in the `?`"). Why the gate
/// went, and why no softer warning replaced it, is argued in
/// `docs/design-decisions.md` under "Sticky has no native cue".
/// `StickyMarkUngatedTests` is what keeps it ungated.
struct StickyMarkEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            SettingsCatalog.gapsAndBorders.stickyWindows,
            caption: L(
                "sticky.caption",
                "Sticky windows stay visible on every "
                    + "Space (%1$@, in %2$@).",
                L(
                    "keybinding.toggle_sticky",
                    "Toggle sticky everywhere"
                ),
                SettingsDestination.shortcuts.title
            )
        ) {
            ToggleRow(
                label: L(
                    "sticky.mark",
                    "Show mark on sticky windows"
                ),
                isOn: $model.config.settings.stickyStyle.mark,
                help: Self.markHelp
            )
        }
    }

    /// Hoisted out of `body` for the type-checker: a
    /// `+`-concatenated literal inside a `ViewBuilder` is the
    /// shape that compiles here and dies on the slower CI runner
    /// (gui.md, SwiftUI traps).
    private static var markHelp: String {
        L(
            "sticky.mark.help",
            "A sticky window can look identical to a normal "
                + "one, so KiwiDesk draws a small mark in its "
                + "top-right corner. The mark is also how a "
                + "refused move explains itself, whether you "
                + "dragged the window or used a shortcut, so "
                + "turning the mark off silences those messages "
                + "too. The Space Bar shows its own sticky badge "
                + "either way; hide the bar as well and no "
                + "sticky signal is left."
        )
    }
}
