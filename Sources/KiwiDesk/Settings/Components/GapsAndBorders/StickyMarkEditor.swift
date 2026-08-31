import KiwiDeskCore
import SwiftUI

/// Sticky window mark settings editor (`StickyMarkUngatedTests`, #414).
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
