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

    /// The button itself, shared with Simple's rows (#2737).
    private let button =
        "Sources/KiwiDesk/Settings/Sections/"
        + "SpaceCustomizeButton.swift"

    /// The row mounts the button unconditionally beside the layout
    /// menu, and the shared view's body draws its `Button` straight
    /// after the state reads, with no branch between.
    @Test("every row draws the button")
    func everyRowDrawsTheButton() throws {
        let cell = try stripped(customize)
        #expect(
            cell.contains(
                "funccustomizeButton(_space:SpaceID)->someView{"
                    + "SpaceCustomizeButton(model:model,space:space){"
                    + "model.nav.spaceOverridesFocus=space}}"
            )
        )
        let view = try stripped(button)
        #expect(
            view.contains(
                // The state, then straight to the Button: no branch
                // can sit between them and withhold it.
                "letstate=Self.state(of:space,in:model)"
                    + "Button(action:open){"
                    + "Image(systemName:\"slider.horizontal.3\")"
            )
        )
        let row = try stripped(
            "Sources/KiwiDesk/Settings/Sections/SpacesSection.swift"
        )
        // Ending at the divider bans a modifier on the call, which
        // could hide the button; it costs a reorder of the row.
        #expect(
            row.contains(
                "SpaceModeMenu(model:model,space:space)"
                    + ".focused($returningRow,equals:space)"
                    + "customizeButton(space)Divider()"
            )
        )
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
    /// The chain is matched whole, up to the builder's closing
    /// brace, so a trailing modifier that hides the button reds;
    /// it costs reordering the chain, which edits this needle.
    @Test("the button is named and valued from its state")
    func buttonIsNamedAndValued() throws {
        let body = try stripped(button)
        let chain: String = [
            ".buttonStyle(.borderless).iconHoverChip()",
            ".help(L(\"spaces.overrides.customize\",",
            "\"Customize…\"))",
            ".accessibilityLabel(L(\"spaces.customize.a11y\",",
            "\"CustomizeSpace%1$@\",space.raw))",
            ".accessibilityValue(",
            "OverrideCountBadge.spokenValue(state))}",
        ].joined()
        #expect(body.contains(chain))
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
