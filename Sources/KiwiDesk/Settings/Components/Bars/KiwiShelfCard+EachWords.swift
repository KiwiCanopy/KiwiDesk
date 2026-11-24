import KiwiDeskCore
import SwiftUI

/// Each bar and Pocket's words (#3612): the Screen or area picker's
/// help and the greyed Pocket rows' sentence.
extension KiwiShelfCard {
    static var scopeHelp: String {
        L(
            "kiwishelf.scope.help",
            "\u{201C}%1$@\u{201D} sets each bar's \u{201C}%2$@\u{201D} "
                + "and \u{201C}%3$@\u{201D} on every screen. Pick a "
                + "screen or area to give it values of its own; "
                + "picking the value set under \u{201C}%1$@\u{201D} "
                + "stores nothing.",
            L("kiwishelf.scope.all", "All screens"),
            L("kiwishelf.show.label", "Show"),
            L("kiwishelf.edge.label", "Position")
        )
    }
    static var oneScreenHelp: String {
        L(
            "kiwishelf.edge.per_screen.one_screen_or_split",
            "Needs a profile with two or more screens, or a screen "
                + "split into areas."
        )
    }
    /// The `?` and hover of a Pocket row that has one value for
    /// every screen, greyed while an area is picked.
    static var everyScreenHelp: String {
        L(
            "kiwishelf.scope.every_screen",
            "Applies on every screen. Choose \u{201C}%1$@\u{201D} above "
                + "to change it.",
            L("kiwishelf.scope.all", "All screens")
        )
    }
}

/// A block in Each bar and Pocket, whose name VoiceOver hears with
/// each of its controls ("Space Bar, Show").
enum ShelfBlock {
    case spaceBar
    case appBar
    case pocket

    @MainActor var name: String {
        switch self {
        case .spaceBar: L("kiwishelf.bar.space_bar", "Space Bar")
        case .appBar: L("kiwishelf.bar.app_bar", "App Bar")
        case .pocket: L("kiwishelf.bar.pocket", "Pocket")
        }
    }

    @MainActor func spoken(_ control: String) -> String {
        L("kiwishelf.per_screen.control.ax", "%1$@, %2$@", name, control)
    }
}
