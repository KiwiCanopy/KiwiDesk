import Foundation
import Testing

/// Both bars stand down through the one
/// `KiwiCore.shelfStandsDown(on:)` — a native-fullscreen Space
/// (#670) or a presentation in front (#1787). A bar surface
/// gating on a user-space read of its own would hide on the
/// first and draw over a slide show, so the bar-building files
/// spell none, bar the `allowed` map's.
@Suite("Shelf stand-down seam (#1787)")
struct ShelfStandDownSeamTests {
    /// The bar-building files, by path prefix under
    /// `Sources/KiwiDeskCore`.
    private static let barFiles = [
        "App/KiwiCore+Shelf", "App/KiwiCore+AppBar",
        "App/KiwiCore+SpaceBar", "Bar/",
    ]

    /// Who may read the user-space verdict anyway, and why.
    private static let allowed: [String: Int] = [
        // `appBarFallback`: the cold start before any display is
        // published, so there is no display to ask about.
        "App/KiwiCore+AppBar.swift": 1
    ]

    @Test("no bar surface reads the user-space verdict itself")
    func barFilesAskTheStandDown() throws {
        let core = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let files = try FileManager.default.subpathsOfDirectory(
            atPath: core.path
        )
        .filter { file in
            file.hasSuffix(".swift")
                && Self.barFiles.contains { file.hasPrefix($0) }
        }
        #expect(files.contains("App/KiwiCore+Shelf.swift"))
        var homes: [String: Int] = [:]
        for file in files {
            // Whitespace out, so a call wrapped before its label
            // still counts.
            let squeezed = SourceScan.stripComments(
                try String(
                    contentsOf: core.appendingPathComponent(file),
                    encoding: .utf8
                )
            ).filter { !$0.isWhitespace }
            let count =
                squeezed.components(
                    separatedBy: "currentSpaceIsUser("
                ).count - 1
                + squeezed.components(
                    separatedBy: "activeSpaceIsUser("
                ).count - 1
            if count > 0 { homes[file] = count }
        }
        #expect(homes == Self.allowed)
    }
}
