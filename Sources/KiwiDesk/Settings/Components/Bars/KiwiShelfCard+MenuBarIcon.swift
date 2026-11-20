import KiwiDeskCore
import SwiftUI

/// What KiwiDesk's menu bar icon shows (#3532): a pop-up under the
/// Show master and its drawer. Never greyed, and no preview: the
/// live menu bar is the preview.
extension KiwiShelfCard {
    var menuBarIconRow: some View {
        let label = SettingsCatalog.bars.kiwishelfMenuBarIcon.text
        let options = AppBarOptions.menuBarIcon
        let selected = shelf.menuBarIcon.wrappedValue
        return DropdownRow(
            label: label,
            spokenValue: options.first { $0.0 == selected }?.1 ?? "",
            help: Self.menuBarIconHelp(options)
        ) {
            Picker(label, selection: shelf.menuBarIcon) {
                ForEach(options, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
        }
        .searchAnchored(SettingsCatalog.bars.kiwishelfMenuBarIcon)
    }

    /// The row's `?`: each choice by its label, then the
    /// several-screen form (#3532 ▸ 10).
    static func menuBarIconHelp(
        _ options: [(KiwiShelf.MenuBarIcon, String)]
    ) -> String {
        func title(_ icon: KiwiShelf.MenuBarIcon) -> String {
            options.first { $0.0 == icon }?.1 ?? ""
        }
        return L(
            "kiwishelf.menu_bar_icon.help",
            "What KiwiDesk's icon in the menu bar shows. %1$@ — the "
                + "KiwiDesk logo while the Space Bar is on screen, and "
                + "the Space instead on any screen where it is "
                + "hidden. %2$@ — always the KiwiDesk logo. %3$@ — "
                + "the Space each screen is on: its icon, else its "
                + "name. %4$@ — the symbol of the layout each of "
                + "those Spaces uses. With several screens, it lists "
                + "each screen's Space in the order the screens are "
                + "arranged, with a thin line between them: Spaces 2 "
                + "and 5 read \u{201C}2 | 5\u{201D}, and "
                + "\u{201C}%4$@\u{201D} shows those two Spaces' layout "
                + "symbols the same way. A Space with tiling off adds "
                + "a pause mark. While a layer other than "
                + "\u{201C}default\u{201D} is on, its icon comes first.",
            title(.auto),
            title(.logo),
            title(.identifier),
            title(.layout)
        )
    }
}
