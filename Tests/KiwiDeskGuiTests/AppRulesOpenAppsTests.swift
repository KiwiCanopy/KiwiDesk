import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// App Rules' Space and Float pickers lead with the open apps (#2297):
/// only those with a bundle id, since a rule matches by bundle id
/// alone, and never the windows beneath the normal
/// layer; the Tile picker keeps its guessed list (#2071).
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

    @Test("a process without a bundle id is never offered for a rule")
    func bundledOnly() {
        let apps = [
            OpenApp(
                app: AppRef(bundleID: "com.apple.Safari", name: "Safari"),
                name: "Safari"
            ),
            OpenApp(
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
                of: "{ Self.ruleCandidates(core) }"
            ) == 1
        )
        #expect(
            selector.occurrences(
                of: "core.openApps(beneathNormal: false)"
            ) == 1
        )
    }
}
