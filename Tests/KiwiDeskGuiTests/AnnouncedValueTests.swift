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
struct AnnouncedValueTests {
    /// File basename → how many labelled pickers/menus it holds.
    private static let labelled: [String: Int] = [
        "AppRuleRow+Facets.swift": 2,
        "SpacesSection+ModePicker.swift": 1,
        "NativeSpacesGroup.swift": 1,
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

    /// The row label the shared shape draws is a SIBLING of the
    /// control, and every control in that shape names itself —
    /// so the text is hidden from VoiceOver or the words arrive
    /// twice. Pinned by needle because the docstring is the
    /// only other place the decision lives.
    @Test("the shared row label is drawn, not spoken")
    func rowLabelIsHidden() throws {
        let source = try Self.source(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "SettingsRowShape.swift"
        )
        let label = try #require(
            source.range(of: "struct SettingsRowLabel")
        )
        #expect(
            source[label.lowerBound...]
                .contains(".accessibilityHidden(true)")
        )
    }

    /// `SettingsSlider` names and values its representation from
    /// its two required arguments; a bare `Slider` announces a
    /// percentage of range, the defect nineteen rows shipped.
    @Test("the slider seam names and values its representation")
    func sliderSeamAnnouncesBoth() throws {
        let source = try Self.source(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "SettingsSlider.swift"
        )
        #expect(source.contains(".accessibilityLabel(label)"))
        #expect(
            source.contains(".accessibilityValue(spokenValue)")
        )
    }

    /// `DropdownRow` names its picker and gives the choice back:
    /// `labelsHidden` drops the pop-up's AX title on device
    /// (General ▸ Language said "menu, 12 items, Deutsch" and
    /// never "Display language" — owner, #812), and a label alone
    /// would take the choice away. The walker above cannot see
    /// this one — the label lands on the `picker` parameter, not
    /// on a `Picker(` spelling — so it is pinned by needle.
    @Test("the dropdown row names its picker and states the choice")
    func dropdownRowAnnouncesBoth() throws {
        let source = try Self.source(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "DropdownRow.swift"
        )
        let row = try #require(source.range(of: "struct DropdownRow"))
        let body = source[row.lowerBound...]
        #expect(body.contains(".accessibilityLabel(label)"))
        #expect(body.contains(".accessibilityValue(spokenValue)"))
    }

    /// A title component carries `.isHeader`, so the headings
    /// rotor walks an area card by card. Each site's count is
    /// its own: a needle over the file would be satisfied by one
    /// surviving title while the other went quiet.
    @Test("title components are rotor headings")
    func titleComponentsAreHeadings() throws {
        let sites: [(String, Int)] = [
            ("Components/Common/SettingsSection.swift", 2),
            ("SettingsDetailPanel.swift", 2),
            ("SettingsHeaderBar.swift", 1),
            ("HomeScreen.swift", 1),
        ]
        for (file, expected) in sites {
            let source = try Self.source(
                "Sources/KiwiDesk/Settings/" + file
            )
            #expect(
                source.occurrences(of: ".accessibilityAddTraits(.isHeader)")
                    == expected,
                Comment(
                    rawValue:
                        "\(file): a title lost its heading trait — "
                        + "the rotor no longer lists it"
                )
            )
        }
    }

    /// A custom-drawn slider holds no keyboard focus of its own;
    /// Tab skipped every one in the tree (owner, #812). The seam
    /// re-earns the Tab stop and the arrow keys — pinned here
    /// because a source needle is all that can hold it, and a
    /// green needle says only that the modifiers are declared:
    /// whether focus lands is a device fact, verified with
    /// keyboard navigation ON.
    @Test("the slider seam holds focus and steps by arrow key")
    func sliderSeamIsKeyboardReachable() throws {
        let source = try Self.source(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "SettingsSlider.swift"
        )
        #expect(source.contains(".focusable(isEnabled)"))
        for key in ["leftArrow", "rightArrow", "upArrow", "downArrow"] {
            #expect(
                source.contains(".onKeyPress(.\(key))"),
                Comment(rawValue: "the slider lost its \(key) step")
            )
        }
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
