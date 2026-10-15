import KiwiDeskCore
import SwiftUI

/// The Hyper move offer's words (#1870). Core hands the moves; the
/// GUI names the rows and writes the sentences (#96).
@MainActor
enum HyperMoveWords {
    /// The offer row's label, by direction.
    static func offer(_ direction: HyperShortcutMove.Direction) -> String {
        switch direction {
        case .toHyper:
            return L(
                "shortcuts.hyper_move.offer",
                "Move my ⌃⌥ letter shortcuts to Hyper…"
            )
        case .back:
            return L(
                "shortcuts.hyper_move.offer_back",
                "Move my Hyper shortcuts back to ⌃⌥…"
            )
        }
    }

    /// The Desktop base's name in the unsaved-changes list.
    static var baseTitle: String {
        L("shortcuts.hyper_move.base", "Go to Desktop modifiers")
    }

    /// Under the reverse offer: why those rows are dimmed.
    static var offCaption: String {
        L(
            "shortcuts.hyper_move.off_caption",
            "Hyper is off, so shortcuts with ✦ are dimmed and don't "
                + "work. Record a Hyper key again, or move them back."
        )
    }

    /// Under the offer while a saved profile other than the loaded
    /// one is being edited.
    static var storedPage: String {
        L(
            "shortcuts.hyper_move.stored_page",
            "Move shortcuts to Hyper while editing the loaded profile."
        )
    }

    /// A dimmed row's hint for VoiceOver and the pointer.
    static var dormantHint: String {
        L(
            "shortcuts.hyper_move.dormant",
            "Hyper is off, so this shortcut doesn't work."
        )
    }

    /// The sheet's title, by direction.
    static func title(_ direction: HyperShortcutMove.Direction) -> String {
        switch direction {
        case .toHyper:
            return L(
                "shortcuts.hyper_move.title",
                "Move shortcuts to Hyper"
            )
        case .back:
            return L(
                "shortcuts.hyper_move.title_back",
                "Move shortcuts back to ⌃⌥"
            )
        }
    }

    /// The sheet's one sentence above the list.
    static func intro(_ direction: HyperShortcutMove.Direction) -> String {
        switch direction {
        case .toHyper:
            return L(
                "shortcuts.hyper_move.intro",
                "Ticked shortcuts move from ⌃⌥ to ✦. One you changed "
                    + "yourself is unticked; tick it to move it too. "
                    + "Nothing changes until you save."
            )
        case .back:
            return L(
                "shortcuts.hyper_move.intro_back",
                "Ticked shortcuts move from ✦ back to ⌃⌥. Nothing "
                    + "changes until you save."
            )
        }
    }

    static var move: String { L("shortcuts.hyper_move.move", "Move") }

    static var cancel: String {
        L("shortcuts.hyper_move.cancel", "Cancel")
    }

    /// The KiwiHub line, which moves with Open Settings.
    static func kiwiHub(settings: String) -> String {
        L(
            "shortcuts.hyper_move.kiwihub",
            "%1$@ and %2$@",
            L("kiwihub.name", "KiwiHub"),
            settings
        )
    }

    /// A line that cannot move: the chord it would take is taken.
    static func taken(chord: String, by name: String) -> String {
        L(
            "shortcuts.hyper_move.taken",
            "%1$@ is taken by %2$@, so this stays.",
            chord,
            name
        )
    }

    /// The Desktop line; the two bases swap for the reverse.
    static func desktop(from: String, to: String) -> String {
        L(
            "shortcuts.hyper_move.desktop",
            "Go to Desktop: %1$@ + digit → %2$@ + digit, including "
                + "Desktops you add later",
            from,
            to
        )
    }

    /// `text` with ✦ spelled "Hyper" for VoiceOver; Hyper is kept
    /// Latin in every catalog, so the name needs no key.
    static func spoken(_ text: String) -> String {
        text.replacingOccurrences(of: ComboSymbols.hyperGlyph, with: "Hyper ")
    }

    /// `combo` as the board draws it.
    static func chord(_ combo: String) -> String {
        guard let parsed = KeyCombo.parse(combo) else { return combo }
        return ComboSymbols.render(parsed, layoutChar: LayoutKeyGlyph.char)
    }

    /// `moves` as "⌃⌥F → ✦F", joined.
    static func chords(_ moves: [HyperShortcutMove.Move]) -> String {
        moves.map { "\(chord($0.from)) → \(chord($0.to))" }
            .joined(separator: "  ")
    }

    /// A Desktop base's modifiers as drawn.
    static func modifiers(_ base: DesktopShortcutBase) -> String {
        guard let combo = KeyCombo.parse(base.combo("1")) else {
            return base.rawValue
        }
        return ComboSymbols.modifierSymbols(combo.modifiers)
    }
}
