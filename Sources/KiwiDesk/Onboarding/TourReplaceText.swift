import KiwiDeskCore

/// The words of the tour's replace question (#3294, owner ruling
/// 2026-11-13), Core handing the counts and the GUI narrating them
/// (#96). `preset` is the picked preset's name, nil for the
/// Suggested starter, which the step never names: those sentences
/// say "suggested" in keys of their own rather than taking a name.
@MainActor
enum TourReplaceText {
    static func title(_ preset: String?) -> String {
        guard let preset else {
            return L(
                "onboarding.start_with.replace_title.suggested",
                "Replace your Spaces with the suggested ones?"
            )
        }
        return L(
            "onboarding.start_with.replace_title",
            "Replace your Spaces with %1$@?",
            preset
        )
    }

    /// The message, and where app rules aim at a Space the pick
    /// drops, the line saying those apps bring it back on demand.
    static func message(
        current: Int,
        preset: String?,
        spaces: Int,
        leftBehind: [SpaceID: Int]
    ) -> String {
        let lead = lead(current: current, preset: preset, spaces: spaces)
        guard !leftBehind.isEmpty else { return lead }
        let targets = SpaceID.numericLexicalSorted(Array(leftBehind.keys))
        let rules = leftBehind.values.reduce(0, +)
        let names = LocalizedList.join(targets.map(\.raw))
        let line =
            preset.map {
                named(names, one: targets.count == 1, preset: $0, rules)
            } ?? suggested(names, one: targets.count == 1, rules)
        return lead + "\n\n" + line
    }

    private static func lead(
        current: Int,
        preset: String?,
        spaces: Int
    ) -> String {
        guard let preset else {
            return L(
                "onboarding.start_with.replace_message.suggested",
                "Your %1$d Spaces and their layouts are replaced by the "
                    + "%2$d suggested for your screens. App rules, "
                    + "shortcuts and looks stay as they are.",
                current,
                spaces
            )
        }
        return L(
            "onboarding.start_with.replace_message",
            "Your %1$d Spaces and their layouts are replaced by "
                + "%2$@'s %3$d. App rules, shortcuts and looks stay as "
                + "they are.",
            current,
            preset,
            spaces
        )
    }

    private static func named(
        _ names: String,
        one: Bool,
        preset: String,
        _ rules: Int
    ) -> String {
        one
            ? L(
                "onboarding.start_with.replace_rules.one",
                "App rules that send apps to Space %1$@ will bring it "
                    + "back when those apps open, since %2$@ leaves it "
                    + "out. App rules affected: %3$d",
                names,
                preset,
                rules
            )
            : L(
                "onboarding.start_with.replace_rules",
                "App rules that send apps to Spaces %1$@ will bring "
                    + "them back when those apps open, since %2$@ "
                    + "leaves them out. App rules affected: %3$d",
                names,
                preset,
                rules
            )
    }

    private static func suggested(
        _ names: String,
        one: Bool,
        _ rules: Int
    ) -> String {
        one
            ? L(
                "onboarding.start_with.replace_rules.suggested.one",
                "App rules that send apps to Space %1$@ will bring it "
                    + "back when those apps open, since the suggested "
                    + "Spaces leave it out. App rules affected: %2$d",
                names,
                rules
            )
            : L(
                "onboarding.start_with.replace_rules.suggested",
                "App rules that send apps to Spaces %1$@ will bring "
                    + "them back when those apps open, since the "
                    + "suggested Spaces leave them out. App rules "
                    + "affected: %2$d",
                names,
                rules
            )
    }
}
