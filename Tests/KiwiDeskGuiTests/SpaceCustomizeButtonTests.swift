import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every Space row carries the Customize button, with or without
/// an override anywhere (#2674, amending #2654's offer), and the
/// row's actions menu stays its second door. The button speaks
/// the count its badge draws, since VoiceOver reads the badge as
/// nothing.
@MainActor
@Suite("Space Customize button (#2674)")
struct SpaceCustomizeButtonTests {
    private func stripped(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        let body = SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace).joined()
        #expect(!body.isEmpty)
        return body
    }

    private let customize =
        "Sources/KiwiDesk/Settings/Sections/"
        + "SpacesSection+Customize.swift"

    /// The row mounts the button unconditionally beside the layout
    /// menu, and the builder returns its `Button` straight after
    /// the count reads, with no builder attribute to branch in.
    @Test("every row draws the button")
    func everyRowDrawsTheButton() throws {
        let cell = try stripped(customize)
        #expect(
            cell.contains(
                "funccustomizeButton(_space:SpaceID)->someView{"
            )
        )
        #expect(
            cell.contains(
                "isFloating:isFloating)returnButton{"
                    + "model.nav.spaceOverridesFocus=space}label:{"
                    + "Image(systemName:\"slider.horizontal.3\")"
            )
        )
        #expect(!cell.contains("@ViewBuilderfunccustomizeButton"))
        let row = try stripped(
            "Sources/KiwiDesk/Settings/Sections/SpacesSection.swift"
        )
        #expect(row.contains("modePicker(space)customizeButton(space)"))
    }

    @Test("the row menu also opens the editor")
    func rowMenuOpensTheEditor() throws {
        let body = try stripped(customize)
        #expect(
            body.contains(
                "funccontextActions(_space:SpaceID)->someView{"
                    + "Button(L(\"spaces.overrides.customize\","
                    + "\"Customize…\")){"
                    + "model.nav.spaceOverridesFocus=space}"
            )
        )
    }

    /// Named, so valued in the same change (gui.md ▸ the
    /// keyboard path): the label replaces nothing the badge said.
    @Test("the button is named and valued from its state")
    func buttonIsNamedAndValued() throws {
        let body = try stripped(customize)
        #expect(
            body.contains(
                ".accessibilityLabel(L(\"spaces.customize.a11y\","
            )
        )
        #expect(
            body.contains(
                ".accessibilityValue("
                    + "OverrideCountBadge.spokenValue(state))"
            )
        )
        #expect(
            body.contains("OverrideCountBadge(state:state)")
        )
    }

    @Test("the spoken value says what the badge draws")
    func spokenValueMatchesTheBadge() {
        LocalizationManager.shared.select("en")
        #expect(
            OverrideCountBadge.spokenValue(.customize) == "None"
        )
        #expect(
            OverrideCountBadge.spokenValue(.custom(3))
                == "3 custom"
        )
        #expect(
            OverrideCountBadge.spokenValue(.saved(2))
                == "2 saved — they apply when it tiles again"
        )
    }
}
