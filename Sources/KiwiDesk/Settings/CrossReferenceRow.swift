import SwiftUI

/// Cross-tab navigation for the settings detail pane: the view
/// owning the sidebar selection injects a navigator, and deep
/// sections render quiet links ("Appearance ▸ App Bar") where
/// their prose points at a control that lives on another tab —
/// a pointer the user can follow instead of a dead end.

private struct SettingsNavigateKey: EnvironmentKey {
    static let defaultValue: @MainActor (SettingsDestination) -> Void = { _ in
    }
}

extension EnvironmentValues {
    /// Jumps the settings window to a sidebar destination.
    var settingsNavigate: @MainActor (SettingsDestination) -> Void
    {
        get { self[SettingsNavigateKey.self] }
        set { self[SettingsNavigateKey.self] = newValue }
    }
}

/// The standard "lives elsewhere" row: one caption sentence with
/// the destination's name linked AT the position the prose puts
/// it, so every pointer at another tab reads the same and the
/// wording can't drift per section.
///
/// **The link's position is the whole point.** This row used to
/// render `Text(prose)` then the link in a fixed-order `HStack`,
/// so the name could only ever land at the END and every
/// `prose:` key had to be authored dangling ("… — edit them
/// in"). That is the defect [localization.md] bans as
/// `+`-concatenated fragments — a translation cannot reorder
/// pieces stitched together in Swift — with an `HStack` doing
/// the stitching instead of a `+`, which is why nothing caught
/// it. It was not hypothetical: `ja`, `ko`, `zh-Hans`,
/// `zh-Hant` and `ru` had each ended their translation on a
/// colon or a bare preposition, because writing a sentence was
/// not available to them.
///
/// So the prose carries a positional specifier for the link,
/// the call site fills it with ``linkSlot``, and this row splits
/// there. `CrossReferenceRowSlotTests` holds that every call
/// site passes one — without the slot the link falls to the end
/// and the defect is back, silently.
///
/// One `Text` rather than an `HStack` of three: a sentence with
/// something in the middle of it has to wrap as a paragraph,
/// which three siblings in a row cannot do whatever a
/// translation's word order asks for.
struct CrossReferenceRow: View {
    /// The formatted sentence, carrying ``linkSlot`` where the
    /// destination's name belongs.
    let prose: String
    let linkTitle: String
    let destination: SettingsDestination
    @Environment(\.settingsNavigate) private var navigate

    /// Pass this as the prose's link argument. U+FFFC is
    /// Unicode's OBJECT REPLACEMENT CHARACTER — "a non-text
    /// object goes here" — so it cannot collide with copy, and
    /// no translator ever sees it: what reaches the catalog is
    /// an ordinary `%N$@` they may put anywhere in the sentence.
    static let linkSlot = "\u{FFFC}"

    var body: some View {
        Text(sentence)
            .font(.caption)
            .foregroundStyle(.secondary)
            .environment(
                \.openURL,
                // The URL below exists only so the run IS a
                // link; with exactly one per row there is
                // nothing to disambiguate, so the destination
                // comes from the stored property rather than
                // from parsing it back out.
                OpenURLAction { _ in
                    navigate(destination)
                    return .handled
                }
            )
    }

    private var sentence: AttributedString {
        let (leading, trailing) = split
        return AttributedString(leading) + link
            + AttributedString(trailing)
    }

    private var link: AttributedString {
        var run = AttributedString(linkTitle)
        run.link = URL(
            string: "kiwidesk-settings://\(destination.rawValue)"
        )
        run.underlineStyle = .single
        // The caption's own colour, never the system link blue:
        // these pointers are prose the reader may follow, not
        // calls to action, and the underline is the affordance.
        run.foregroundColor = .secondary
        return run
    }

    /// The prose either side of the slot. A prose WITHOUT one
    /// puts the link at the end — the shape this row had before
    /// the sentence could place it. Kept so a missed call site
    /// still renders a followable pointer rather than losing
    /// navigation outright; `CrossReferenceRowSlotTests` is what
    /// stops it being reached.
    private var split: (String, String) {
        guard let slot = prose.range(of: Self.linkSlot) else {
            return (prose + " ", "")
        }
        return (
            String(prose[..<slot.lowerBound]),
            String(prose[slot.upperBound...])
        )
    }
}
