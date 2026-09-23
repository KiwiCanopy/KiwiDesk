import KiwiDeskCore
import SwiftUI

/// The App Rules card's prose (#1022): every sentence the
/// section draws, the section owning the views and this the
/// words they are handed.
extension AppRulesSection {
    /// What an empty list says.
    static var emptyProse: String {
        L(
            "app_rules.empty",
            "Apps with no rule tile normally, in whichever "
                + "Space you open them."
        )
    }

    /// Computed per read, never stored: a `static let` resolves
    /// `L()` once and keeps that locale for the process (#1311).
    static var noSpacesProse: String {
        L(
            "app_rules.no_spaces",
            "This profile has no Spaces yet, so there is nothing "
                + "to open an app in. Add one in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    /// The caption carries the rule behind a missing clear
    /// button. Must-know information never lives only in a
    /// popover, and a `GreyOut` inside a `ForEach` may not stamp a
    /// sentence under every row — so the one copy sits here, above
    /// the list and outside every dimmed subtree (#815, #1022).
    var rulesCaption: String {
        if overrideBase != nil {
            return L(
                "app_rules.override.caption",
                "Space and float rules made here apply to this "
                    + "profile only. Dimmed facets are inherited "
                    + "from the app-wide base rules and stay "
                    + "in sync with them; changing a facet "
                    + "overrides it for this profile, and "
                    + "deleting a row removes inherited rules "
                    + "here. To edit the base rules themselves, "
                    + "switch back to the currently "
                    + "loaded profile in the header's picker."
            )
        }
        return L(
            "app_rules.section.caption",
            "What an app should do when it opens. An app that "
                + "tiles needs a Space to open in."
        )
    }

    /// The `?` beside the heading, in the order a newcomer meets
    /// the parts. `app_rules.float.help` is reused verbatim as an
    /// argument rather than restated, so the float explanation
    /// exists once; the title-pattern paragraph joins only where
    /// the mode offers patterns at all.
    ///
    /// It deliberately does NOT restate "an app that tiles needs
    /// a Space": the always-visible caption says it, and a second
    /// copy here made this the longest help string in the app —
    /// past `desktops.help`, on a window whose minimum height is
    /// 540 pt (ui-designer, 2026-09-22). The remembered-Space
    /// exception rides the last paragraph rather than the first,
    /// being a precedence detail. That the user travels with a
    /// window they OPEN is #1599's launch follow, stated in the
    /// first paragraph beside the rule it follows.
    var sectionHelp: String {
        var text = L(
            "app_rules.section.help",
            "**%1$@** — the app's windows go to that Space, "
                + "whatever Space you are in, and opening the app "
                + "takes you there with them.\n\n%2$@\n\nThe two "
                + "combine: a floating window still belongs to "
                + "its Space, it simply is not tiled inside it. A "
                + "window KiwiDesk already remembers keeps the "
                + "Space it was last in, whichever rule applies.",
            L("app_rules.space", "Opens in"),
            L(
                "app_rules.float.help",
                "Floating takes this app's matching windows out "
                    + "of tiling: each keeps its last position "
                    + "and size and stays above the tiled "
                    + "windows, instead of snapping into one "
                    + "Space's grid.\n\nThis is per-app floating "
                    + "— not the **Floating** layout mode, which "
                    + "floats every window in a Space."
            )
        )
        if offersTitles {
            text +=
                "\n\n"
                + L(
                    "app_rules.section.help.titles",
                    "%1$@ matches a fragment of a window's "
                        + "title, so an app can float some of "
                        + "its windows and tile the rest.",
                    L(
                        "app_rules.float.titled.resting",
                        "Floats if titled"
                    )
                )
        }
        return text
    }
}
