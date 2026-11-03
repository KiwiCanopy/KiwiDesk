import Foundation

/// What an empty Pocket's click says (#2941 ▸ Ruling): how a window
/// goes in, each chord read live through the GUI's one hook and a
/// line shown only while its key is bound, then the Pocket's two
/// Settings rows. State alone, read as the peek shows.
extension KiwiCore {
    func pocketEmptyState() -> BarPeekContent.Empty {
        let hooks = barMenuHooks
        var lines: [BarPeekContent.Empty.Line] = []
        if let chord = hooks.pocketVerbChord(.pocket) {
            // `pocket` puts the out window back before it marks the
            // focus, so the sentence says what the key would do.
            let out = state.pocketPutBackNext(focused: focusedWindowID)
            lines.append(
                Self.pocketLine(chord) { key in
                    out == nil
                        ? L(
                            "pocket.list.empty.focused",
                            "Drag a window here, or press %1$@ to pocket "
                                + "the focused window right away.",
                            key
                        )
                        : L(
                            "pocket.list.empty.out",
                            "Drag a window here, or press %1$@ to put "
                                + "back the one you used last.",
                            key
                        )
                }
            )
        } else {
            // Names the command, never the feature, through its own
            // label key (#818, #2941 ▸ 2).
            let text = L(
                "pocket.list.empty.no_shortcut",
                "Drag a window here to pocket it, or set a shortcut for "
                    + "%1$@ in Settings.",
                L("keybinding.pocket", "Pocket or take out")
            )
            lines.append(.init(drawn: text, spoken: text))
        }
        if let chord = hooks.pocketVerbChord(.togglePocketWindow) {
            lines.append(
                Self.pocketLine(chord) { key in
                    L(
                        "pocket.list.empty.toggle",
                        "Press %1$@ to turn Pocket on or off for the "
                            + "focused window.",
                        key
                    )
                }
            )
        }
        return BarPeekContent.Empty(
            title: L("pocket.list.empty.title", "Your Pocket is empty"),
            lines: lines,
            rows: [
                .init(
                    title: L(
                        "pocket.list.empty.shortcuts",
                        "Pocket Shortcuts…"
                    ),
                    landing: .pocketShortcuts
                ),
                .init(
                    // The words of the row it lands on, one key.
                    title: L(
                        "shortcuts.pocket_app.add",
                        "Give an app its own Pocket key…"
                    ),
                    landing: .pocketKeys
                ),
            ]
        )
    }

    /// One sentence built twice from `frame`: the chord drawn, then
    /// spoken as words (#2601).
    static func pocketLine(
        _ chord: RenderedChord,
        _ frame: (String) -> String
    ) -> BarPeekContent.Empty.Line {
        .init(drawn: frame(chord.drawn), spoken: frame(chord.spoken))
    }
}
