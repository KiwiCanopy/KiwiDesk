import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Tile picker lists the apps the guess floated (#2071): only
/// the Tile role is handed that source, the popover branches on it,
/// and a row's caption names its open windows.
@Suite("Guessed-app Tile picker (#2071)")
@MainActor
struct GuessedAppPickerTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk/Settings")

    private func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        )
    }

    @Test("a caption names the first open window and counts the rest")
    func caption() {
        LocalizationManager.shared.select("en")
        #expect(GuessedAppRows.caption([]) == nil)
        #expect(GuessedAppRows.caption(["Steam"]) == "Steam")
        #expect(GuessedAppRows.caption([""]) == "Untitled window")
        #expect(
            GuessedAppRows.caption(["Steam", "Friends", "Chat"])
                == "Steam and more: 2"
        )
    }

    @Test("only the Tile picker is handed the guessed apps")
    func onlyTileIsGuessed() throws {
        let tile = try source("Sections/AppRulesSection+Automatic.swift")
        #expect(
            tile.occurrences(of: "guessed: { model.core.guessedFloatApps() },")
                == 1
        )
        let lists = try source("Sections/AppRulesSection+Lists.swift")
        #expect(lists.occurrences(of: "guessed:") == 0)
        let selector = try source(
            "Components/Common/AppRuleControls.swift"
        )
        #expect(selector.occurrences(of: "guessed: guessed") == 1)
    }

    /// The popover reads the source when it opens and keeps the
    /// draft's own Tile list out, as the full list does.
    @Test("the popover branches on the source and honours exclude")
    func popoverBranches() throws {
        let picker = try source("Components/Common/AppPickerButton.swift")
        #expect(picker.contains("if let guessed {"))
        #expect(picker.contains("guessedPopover(guessed())"))
        #expect(
            picker.contains(
                "apps.filter { !exclude.contains($0.bundleID) }"
            )
        )
        #expect(picker.contains("Text(GuessedAppRows.hint)"))
        let rows = try source("Components/Common/GuessedAppRows.swift")
        #expect(rows.contains("if apps.isEmpty {"))
        #expect(rows.contains("Text(Self.empty)"))
        #expect(rows.contains(".accessibilityElement(children: .combine)"))
    }
}
