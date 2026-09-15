import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Every GUI site that AUTHORS a layer seeds it with the app-chrome
/// rows — ⌃⌥K and ⌃⌥, — through the ONE `appChromeRows` the base
/// seed also takes (#602, #1381). A hand-listed `[showShortcutsRow()]`
/// beside the seam is how a second chrome row lands in the base
/// layer and nowhere else, so this is a census over `KeyLayer(` in
/// the GUI tree: a site either takes the seam or is ruled out in
/// `allowed` with its reason.
@Suite("New layers carry the app-chrome rows")
struct LayerChromeSeedTests {
    /// `KeyLayer(` sites that seed nothing, and why.
    private static let allowed: [String: String] = [
        // The live-apply session mirror re-creates a layer the
        // user already authored in the draft; it seeds nothing.
        "SettingsModel+LiveApply.swift": "session mirror of an authored layer"
    ]

    @Test("every layer-authoring site seeds through appChromeRows")
    func layerSitesSeedThroughTheSeam() throws {
        let gui = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var seeding: [String] = []
        for file in try SourceScan.swiftSources(under: gui) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            guard source.contains("KeyLayer(") else { continue }
            let name = file.lastPathComponent
            if Self.allowed[name] != nil { continue }
            #expect(
                source.contains(
                    "bindings: DefaultKeybindings.appChromeRows()"
                ),
                "\(name) authors a layer without the chrome seam"
            )
            #expect(
                !source.contains("showShortcutsRow()"),
                "\(name) hand-lists a chrome row beside the seam"
            )
            seeding.append(name)
        }
        // Non-vacuity, and the register both ways: a ruled-out
        // site that stops constructing a layer is a stale entry.
        #expect(!seeding.isEmpty, "no GUI site authors a layer")
        for name in Self.allowed.keys {
            let file = try #require(
                try SourceScan.swiftSources(under: gui).first {
                    $0.lastPathComponent == name
                }
            )
            #expect(
                SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                ).contains("KeyLayer("),
                "\(name) is ruled out but constructs no layer"
            )
        }
    }
}
