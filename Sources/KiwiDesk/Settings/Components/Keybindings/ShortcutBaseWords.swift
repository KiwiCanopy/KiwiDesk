import KiwiDeskCore
import SwiftUI

/// The "Shortcuts use" switch's words (#2460). Core hands the base
/// and the rows; the GUI names them and writes the sentences (#96).
@MainActor
enum ShortcutBaseWords {
    /// The row's label, the save pill's and the census's.
    static var title: String {
        L("shortcuts.base", "Shortcuts use")
    }

    static var help: String {
        L(
            "shortcuts.base.help",
            "Pick ✦ to put KiwiDesk's shortcuts on the Hyper key. A "
                + "shortcut you set on another key stays where you put "
                + "it, and one whose ✦ key another shortcut holds "
                + "stays on ⌃⌥."
        )
    }

    /// Under the switch while a key is set.
    static var caption: String {
        L(
            "shortcuts.base.caption",
            "✦ moves every ⌃⌥ shortcut to Hyper, keeping "
                + "⇧ and ⌘. %1$@ takes ✦⌥, since ⇧⌘3–5 are "
                + "macOS's screenshots. Resize shortcuts stay on "
                + "⌥⌘. Applies to all profiles when you save.",
            L("shortcuts.go_to_desktop", "Go to Desktop")
        )
    }

    /// Under the greyed switch while no key is set.
    static var noKey: String {
        L("shortcuts.base.no_key", "Set a Hyper key above to use ✦.")
    }

    /// Under the switch while the base is ✦ and no key is set.
    static var keyOff: String {
        L(
            "shortcuts.base.key_off",
            "Hyper is off, so shortcuts with ✦ are dimmed and don't "
                + "work. Record a Hyper key again, or pick ⌃⌥."
        )
    }

    /// Under the greyed switch while a saved profile other than the
    /// loaded one is being edited.
    static var storedPage: String {
        L(
            "shortcuts.base.stored_page",
            "Change this while editing the loaded profile."
        )
    }

    /// The list's header; the count last (localization.md).
    static func leftHeader(_ count: Int) -> String {
        L("shortcuts.base.left", "Still on ⌃⌥: %1$d", count)
    }

    /// One left-behind row, its reason in the same frame.
    static func line(
        _ left: ShortcutBaseLeftRow,
        config: GuiConfig
    ) -> String {
        let name = KeybindingCatalog.localizedName(
            of: left.row,
            config: config
        )
        let chord = chord(left.row.combo)
        switch left.reason {
        case .predates:
            return L(
                "shortcuts.base.left.predates",
                "%1$@ (%2$@): from before this update",
                name,
                chord
            )
        case .taken(let target, let holder):
            return L(
                "shortcuts.base.left.taken",
                "%1$@ (%2$@): %3$@ is taken by %4$@",
                name,
                chord,
                Self.chord(target),
                KeybindingCatalog.localizedName(of: holder, config: config)
            )
        case .ownChoice:
            return L(
                "shortcuts.base.left.own",
                "%1$@ (%2$@): you set this one yourself",
                name,
                chord
            )
        case .leftOutHere:
            return L(
                "shortcuts.base.left.left_out",
                "%1$@ (%2$@): this profile leaves it out",
                name,
                chord
            )
        case .profile(let profile):
            return L(
                "shortcuts.base.left.profile",
                "%1$@ (%2$@): “%3$@” sets its own",
                name,
                chord,
                profile
            )
        }
    }

    /// The segment titles, drawn as glyphs.
    static func glyphs(_ base: ShortcutBase) -> String {
        ComboSymbols.modifierSymbols(
            base == .hyper ? .hyper : [.control, .option]
        )
    }

    /// What VoiceOver reads for the selection, never the glyphs.
    static func spoken(_ base: ShortcutBase, keySet: Bool) -> String {
        switch base {
        case .standard:
            L("shortcuts.base.spoken.standard", "Control-Option")
        case .hyper where keySet:
            L("shortcuts.hyper_key.name", "Hyper")
        case .hyper:
            L("shortcuts.base.spoken.no_key", "Hyper, no key set")
        }
    }

    /// A dimmed row's hint for VoiceOver and the pointer.
    static var dormantHint: String {
        L(
            "shortcuts.hyper_move.dormant",
            "Hyper is off, so this shortcut doesn't work."
        )
    }

    /// `combo` as the board draws it.
    static func chord(_ combo: String) -> String {
        guard let parsed = KeyCombo.parse(combo) else { return combo }
        return ComboSymbols.render(parsed, layoutChar: LayoutKeyGlyph.char)
    }
}
