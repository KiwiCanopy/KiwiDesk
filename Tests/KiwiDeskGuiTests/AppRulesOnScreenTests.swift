import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// App Rules' Space and Float pickers lead with the apps on screen
/// now (#2297): only those with a bundle id, since a rule matches
/// by bundle id alone, and never the windows beneath the normal
/// layer; the Tile picker keeps its guessed list (#2071).
@Suite("App Rules ▸ On screen now (#2297)")
@MainActor
struct AppRulesOnScreenTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk/Settings")

    private func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        )
    }

    @Test("a process without a bundle id is never offered for a rule")
    func bundledOnly() {
        let apps = [
            OnScreenApp(
                app: AppRef(bundleID: "com.apple.Safari", name: "Safari"),
                name: "Safari"
            ),
            OnScreenApp(
                app: AppRef(bundleID: nil, name: "sketchybar"),
                name: "sketchybar"
            ),
        ]
        #expect(
            AppSelector.ruleCandidates(apps).map(\.key)
                == ["com.apple.safari"]
        )
    }

    @Test("Space and Float take the section, Tile does not")
    func wiring() throws {
        let needle =
            "onScreen: { model.core.appsOnScreen(beneathNormal: false) }"
        let lists = try source("Sections/AppRulesSection+Lists.swift")
        #expect(lists.occurrences(of: needle) == 2)
        let tile = try source("Sections/AppRulesSection+Automatic.swift")
        #expect(tile.occurrences(of: "onScreen:") == 0)
        let selector = try source(
            "Components/Common/AppRuleControls.swift"
        )
        #expect(
            selector.occurrences(
                of: "onScreen: onScreen.map { read in "
                    + "{ Self.ruleCandidates(read()) } }"
            ) == 1
        )
    }
}
