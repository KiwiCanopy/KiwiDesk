import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// App Rules' Space and Float pickers lead with the open apps (#2297),
/// one without a bundle id named by its process name, which a rule
/// matches (#3211), never the windows beneath the normal layer; the
/// Tile picker keeps its guessed list (#2071).
@Suite("App Rules ▸ Open apps (#2297)")
@MainActor
struct AppRulesOpenAppsTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk/Settings")

    private func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        )
    }

    @Test("Space and Float take the section, Tile does not")
    func wiring() throws {
        let needle = "openAppsOf: model.core"
        let lists = try source("Sections/AppRulesSection+Lists.swift")
        #expect(lists.occurrences(of: needle) == 2)
        let tile = try source("Sections/AppRulesSection+Automatic.swift")
        #expect(tile.occurrences(of: "openAppsOf:") == 0)
        let selector = try source(
            "Components/Common/AppRuleControls.swift"
        )
        #expect(
            selector.occurrences(
                of: "core.openApps(beneathNormal: false)"
            ) == 1
        )
    }
}
