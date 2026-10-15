import KiwiDeskCore

/// A ready-made prompt's localized caption and text (#1685 ▸
/// Ruling 6a), the one switch a new prompt row fills. Each makes
/// the AI app ask the user one question at a time, so it works
/// pasted and sent unchanged. Layout names are the Layouts page's
/// own labels, interpolated (#818).
enum AIReadyPrompt {
    /// The row's one-line caption; nil for a key that is no
    /// ready-made prompt.
    @MainActor static func caption(for key: AIKey) -> String? {
        switch key {
        case .promptLook:
            return L(
                "ai.prompt.look.caption",
                "The vibe, the colors or your wallpaper\u{2019}s, and "
                    + "how the bars look."
            )
        case .promptMigrate:
            return L(
                "ai.prompt.migrate.caption",
                "Paste your old config, and your AI app rebuilds it "
                    + "in KiwiDesk and tells you what has no match."
            )
        case .promptAppRules:
            return L(
                "ai.prompt.app_rules.caption",
                "Which apps float, and which open in which Space."
            )
        case .promptSpaces:
            return L(
                "ai.prompt.spaces.caption",
                "How many Spaces, what goes where, and each "
                    + "one\u{2019}s layout."
            )
        case .copySetupPrompt:
            return nil
        }
    }

    /// The text Copy puts on the clipboard; nil for a key that is
    /// no ready-made prompt.
    @MainActor static func text(for key: AIKey) -> String? {
        switch key {
        case .promptLook:
            // Wallpaper by screenshot: reading it raises a TCC
            // prompt (#1685 ▸ Ruling 6b).
            return L(
                "ai.prompt.look.text",
                "Help me make my own look in KiwiDesk. Ask me, one "
                    + "question at a time: what vibe I want, which "
                    + "colors (or offer to match my wallpaper from a "
                    + "screenshot), how the bars should look (edge, "
                    + "thickness, glass or solid), and what I want to "
                    + "keep. Show each change live. I\u{2019}ll say "
                    + "\u{201C}keep\u{201D} when I\u{2019}m happy."
            )
        case .promptMigrate:
            // Shortcuts save at once (#1685 ▸ Ruling 6c), so the
            // AI app shows them before it adds them.
            return L(
                "ai.prompt.migrate.text",
                "Help me move to KiwiDesk from another window "
                    + "manager. Ask me, one question at a time: which "
                    + "one I used (such as AeroSpace, yabai, Amethyst "
                    + "or Rectangle), and to paste its config. Then "
                    + "rebuild my Spaces, layouts and gaps, my app "
                    + "rules and my shortcuts, and tell me what has "
                    + "no match in KiwiDesk. Show each change live, "
                    + "but show me the shortcuts before you add them, "
                    + "since they save at once. I\u{2019}ll say "
                    + "\u{201C}keep\u{201D} when I\u{2019}m happy."
            )
        case .promptAppRules:
            return L(
                "ai.prompt.app_rules.text",
                "Help me set up app rules in KiwiDesk. Ask me, one "
                    + "question at a time: which apps should float, "
                    + "which should open in a certain Space, and "
                    + "whether only some of an app\u{2019}s windows "
                    + "should float, by their title. Show each change "
                    + "live. I\u{2019}ll say \u{201C}keep\u{201D} "
                    + "when I\u{2019}m happy."
            )
        case .promptSpaces:
            let names = spacesLayouts.map(\.displayName)
            return L(
                "ai.prompt.spaces.text",
                "Help me set up my Spaces in KiwiDesk. Ask me, one "
                    + "question at a time: how many Spaces I want, "
                    + "what goes where, which layout each one gets "
                    + "(%1$@, %2$@, %3$@, %4$@, %5$@, %6$@ or %7$@), "
                    + "and how much gap I want between windows. Show "
                    + "each change live. I\u{2019}ll say "
                    + "\u{201C}keep\u{201D} when I\u{2019}m happy.",
                names[0],
                names[1],
                names[2],
                names[3],
                names[4],
                names[5],
                names[6]
            )
        case .copySetupPrompt:
            return nil
        }
    }

    /// The layouts the Spaces prompt offers, in the order it
    /// names them — every `LayoutMode` once.
    static let spacesLayouts: [LayoutMode] = [
        .scrolling, .monocle, .stack, .track, .bsp, .grid,
        .floating,
    ]
}
