import KiwiDeskCore

/// The words of the tour's replace question (#3294, owner ruling
/// 2026-11-13), Core handing the counts and the GUI narrating them
/// (#96).
@MainActor
enum TourReplaceText {
    static func title(_ preset: String) -> String {
        L(
            "onboarding.start_with.replace_title",
            "Replace your Spaces with %1$@?",
            preset
        )
    }

    /// The message, and where app rules aim at a Space the preset
    /// drops, the line saying those apps bring it back on demand.
    static func message(
        current: Int,
        preset: String,
        spaces: Int,
        leftBehind: [SpaceID: Int]
    ) -> String {
        let lead = L(
            "onboarding.start_with.replace_message",
            "Your %1$d Spaces and their layouts are replaced by "
                + "%2$@'s %3$d. App rules, shortcuts and looks stay as "
                + "they are.",
            current,
            preset,
            spaces
        )
        guard !leftBehind.isEmpty else { return lead }
        let targets = SpaceID.numericLexicalSorted(Array(leftBehind.keys))
        let rules = leftBehind.values.reduce(0, +)
        let names = LocalizedList.join(targets.map(\.raw))
        let line =
            targets.count == 1
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
        return lead + "\n\n" + line
    }
}
