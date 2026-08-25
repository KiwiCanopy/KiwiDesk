import Foundation
import Testing

/// A control that is NAMED with `.accessibilityLabel` owes its
/// VALUE back with `.accessibilityValue` (#812; the rule is
/// gui.md ▸ the keyboard path, and the shipped instance was the
/// App Rules facet menus, #678 turn 20a rule 3).
///
/// `.accessibilityLabel` replaces what VoiceOver derived, and
/// for a `Picker` or a `Menu` the derived announcement is the
/// current CHOICE — so the modifier that gives the control a
/// name is the one that takes its value away, and nothing looks
/// wrong on screen, where a sighted reader still sees the
/// choice. The Spaces mode picker shipped that way for its
/// whole life: "Layout mode for this Space, pop-up button", and
/// never which mode.
///
/// `AppRulesCensusRenderTests` pins the two facets by their own
/// value expressions. This suite is the general form: every
/// `Picker(` and `Menu {` under the chrome roots whose OWN
/// modifier chain carries `.accessibilityLabel(` must carry
/// `.accessibilityValue(` in the same chain. A `Toggle` is out
/// of scope on purpose — its on/off IS a value AppKit keeps
/// through a label — and a `SettingsSlider` names and values
/// itself by two required arguments, which the compiler holds.
///
/// The census below is the one copy of which controls are
/// labelled at all, held EXACTLY: a control that gains a label
/// joins it in the same change, so the scan cannot go quiet by
/// matching nothing.
///
/// Stated blind spots, deliberate: the walker matches only the
/// `Picker(` and `Menu {` spellings — a `Menu("Title") { … }`
/// string-init is invisible to it (none exists under the roots
/// today), and a label that lands on a wrapper's PARAMETER
/// (`DropdownRow`) is out of its reach, which is why that
/// wrapper is pinned by its own needle below and its nil escape
/// by an `allowed` map.
struct AnnouncedValueTests {
    /// File basename → how many labelled pickers/menus it holds.
    private static let labelled: [String: Int] = [
        "AppRuleRow+Facets.swift": 2,
        "SpacesSection+ModePicker.swift": 1,
        "DesktopsGroup.swift": 1,
        "ProfileHeader.swift": 1,
        "KeybindingAppGroup+Behavior.swift": 1,
    ]

    @Test("a named picker or menu gives its value back")
    func namedControlsStateTheirValue() throws {
        var found: [String: Int] = [:]
        for url in try ChromeScanRoots.sources(from: #filePath) {
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            for chain in Self.controlChains(in: source)
            where chain.contains(".accessibilityLabel(") {
                found[url.lastPathComponent, default: 0] += 1
                #expect(
                    chain.contains(".accessibilityValue("),
                    Comment(
                        rawValue:
                            "\(url.lastPathComponent): a Picker "
                            + "or Menu named with "
                            + ".accessibilityLabel no longer "
                            + "announces its choice — the label "
                            + "replaced it; give the value back "
                            + "with .accessibilityValue in the "
                            + "same chain"
                    )
                )
            }
        }
        #expect(
            found == Self.labelled,
            Comment(
                rawValue:
                    "the census of labelled pickers/menus "
                    + "changed: found \(found) — update "
                    + "`labelled` in the same change, so the "
                    + "scan stays proven to see every site"
            )
        )
    }

    // MARK: - Walker

    /// Every `Picker(…)` / `Menu {…}` in `source`, each as the
    /// text of its OWN trailing modifier chain: the call, its
    /// closures, then every `.modifier(…)` / `.modifier {…}`
    /// that follows without a break. A modifier on an enclosing
    /// container is not the control's and is not returned.
    static func controlChains(in source: String) -> [String] {
        let text = Array(source)
        var chains: [String] = []
        let controls: [(String, Character)] = [
            ("Picker", "("), ("Menu", "{"),
        ]
        for (needle, opener) in controls {
            var cursor = 0
            while let start = Self.find(
                needle,
                in: text,
                from: cursor
            ) {
                var i = start + needle.count
                // The call's own argument list and closures.
                guard Self.skipRun(text, &i, opener: opener)
                else {
                    cursor = i
                    continue
                }
                while Self.skipTrailingClosure(text, &i) {}
                // Then the modifier chain, one `.name(…) {…}`
                // at a time.
                let chainStart = i
                while Self.skipModifier(text, &i) {}
                chains.append(String(text[chainStart..<i]))
                cursor = i
            }
        }
        return chains
    }

    /// `needle` as a whole identifier: not preceded by an
    /// identifier character (`SegmentedPicker(` is not a
    /// `Picker(`), and immediately followed by the opener.
    private static func find(
        _ needle: String,
        in text: [Character],
        from cursor: Int
    ) -> Int? {
        let word = Array(needle)
        var i = cursor
        while i + word.count < text.count {
            if Array(text[i..<i + word.count]) == word,
                i == 0 || !Self.isIdentifier(text[i - 1]),
                !Self.isIdentifier(text[i + word.count])
            {
                return i
            }
            i += 1
        }
        return nil
    }

    private static func isIdentifier(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "_"
    }

    /// Skips whitespace then one balanced run opened by
    /// `opener`; false (cursor untouched) when none follows.
    private static func skipRun(
        _ text: [Character],
        _ i: inout Int,
        opener: Character
    ) -> Bool {
        let close: Character = opener == "(" ? ")" : "}"
        var probe = i
        while probe < text.count, text[probe].isWhitespace {
            probe += 1
        }
        guard probe < text.count, text[probe] == opener,
            SourceScan.balanced(
                text,
                from: &probe,
                open: opener,
                close: close
            ) != nil
        else { return false }
        i = probe
        return true
    }

    /// Skips one trailing closure, bare (`{…}`) or labelled
    /// (`label: {…}` — a `Menu`'s label is one); false when
    /// none follows.
    private static func skipTrailingClosure(
        _ text: [Character],
        _ i: inout Int
    ) -> Bool {
        if Self.skipRun(text, &i, opener: "{") { return true }
        var probe = i
        while probe < text.count, text[probe].isWhitespace {
            probe += 1
        }
        guard probe < text.count, Self.isIdentifier(text[probe])
        else { return false }
        while probe < text.count, Self.isIdentifier(text[probe]) {
            probe += 1
        }
        guard probe < text.count, text[probe] == ":" else {
            return false
        }
        probe += 1
        guard Self.skipRun(text, &probe, opener: "{") else {
            return false
        }
        i = probe
        return true
    }

    /// Skips one `.identifier` plus any `(…)` and `{…}` runs
    /// attached to it; false at the end of the chain.
    private static func skipModifier(
        _ text: [Character],
        _ i: inout Int
    ) -> Bool {
        var probe = i
        while probe < text.count, text[probe].isWhitespace {
            probe += 1
        }
        guard probe < text.count, text[probe] == "." else {
            return false
        }
        probe += 1
        guard probe < text.count, Self.isIdentifier(text[probe])
        else { return false }
        while probe < text.count, Self.isIdentifier(text[probe]) {
            probe += 1
        }
        i = probe
        while Self.skipRun(text, &i, opener: "(")
            || Self.skipRun(text, &i, opener: "{")
        {}
        return true
    }

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(path),
                encoding: .utf8
            )
        )
    }
}
