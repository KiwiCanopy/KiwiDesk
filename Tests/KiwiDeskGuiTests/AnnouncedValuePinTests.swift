import Foundation
import Testing

/// The needle-pinned half of the announced-vs-declared family
/// (#812) — split from `AnnouncedValueTests` at the §2.1
/// ceiling. That suite owns the walker and the labelled census;
/// this one pins the individual seams a walker cannot reach:
/// the shared row label, the slider seam, `DropdownRow`, the
/// heading census, the nil-spoken-value map and the save pill's
/// cancellable announcement. The docstrings on each test carry
/// their own arguments.
struct AnnouncedValuePinTests {
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
    /// rotor walks an area card by card. The scan DERIVES which
    /// files declare the trait and the map only makes silence
    /// loud (the `labelled` idiom above): a hand list per file
    /// would never learn of a fifth title component, which is
    /// exactly how Home's two labels stayed the app's only
    /// headings (architect review, 2026-08-24).
    private static let headings: [String: Int] = [
        "SettingsSection.swift": 2,
        "SettingsDetailPanel.swift": 2,
        "SettingsHeaderBar.swift": 1,
        "HomeScreen.swift": 1,
    ]

    @Test("title components are rotor headings")
    func titleComponentsAreHeadings() throws {
        var found: [String: Int] = [:]
        for url in try ChromeScanRoots.sources(from: #filePath) {
            let count = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            .occurrences(of: ".accessibilityAddTraits(.isHeader)")
            if count > 0 {
                found[url.lastPathComponent] = count
            }
        }
        #expect(
            found == Self.headings,
            Comment(
                rawValue:
                    "the heading census changed: found \(found) "
                    + "— a title lost its trait, or a new title "
                    + "component joins `headings` in the same "
                    + "change"
            )
        )
    }

    /// `DropdownRow`'s `spokenValue: nil` escape exists for a
    /// `Toggle`, whose on/off survives a label — around a
    /// `Picker` it re-ships the #812 defect with every guard
    /// green, because the walker cannot see a label that lands
    /// on a parameter. The map is the one copy of who may.
    private static let nilSpokenValue: [String: Int] = [
        "LoginItemCard.swift": 1
    ]

    @Test("a nil spoken value is for a Toggle, and enumerated")
    func nilSpokenValuesAreEnumerated() throws {
        var found: [String: Int] = [:]
        for url in try ChromeScanRoots.sources(from: #filePath) {
            let count = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            .occurrences(of: "spokenValue: nil")
            if count > 0 {
                found[url.lastPathComponent] = count
            }
        }
        #expect(
            found == Self.nilSpokenValue,
            Comment(
                rawValue:
                    "a new `spokenValue: nil` site: \(found) — "
                    + "legal only around a control whose state "
                    + "IS its value; join the map with the "
                    + "argument, or state the value"
            )
        )
    }

    /// The save pill's appearance announcement is cancellable —
    /// a Save inside the delay must not hear "Unsaved changes"
    /// over a clean tree (code review, 2026-08-24). A needle on
    /// the two halves the fix is made of; whether the cancel
    /// wins the race is a device fact.
    @Test("the pill announcement cancels with the pill")
    func pillAnnouncementIsCancellable() throws {
        let source = try Self.source(
            "Sources/KiwiDesk/Settings/SettingsFooter.swift"
        )
        #expect(source.contains("pendingAnnouncement?.cancel()"))
        #expect(source.contains("execute: work"))
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
        #expect(
            source.contains(
                ".focusable(isEnabled, interactions: .edit)"
            )
        )
        for key in ["leftArrow", "rightArrow", "upArrow", "downArrow"] {
            #expect(
                source.contains(".onKeyPress(.\(key))"),
                Comment(rawValue: "the slider lost its \(key) step")
            )
        }
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
