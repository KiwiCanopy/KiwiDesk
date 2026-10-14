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
