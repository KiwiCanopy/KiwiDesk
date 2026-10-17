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

    /// Every cue stands down through the same verdict as the bars
    /// (#2348): a cue reading the presentation beside it is left
    /// behind when the verdict gains a case, so the presentation
    /// read is spelled inside the verdict alone.
    @Test("the cues ask the shelf's verdict, never a part of it")
    func cuesAskTheStandDown() throws {
        let core = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var presentation: [String: Int] = [:]
        for url in try SourceScan.swiftSources(under: core) {
            let source = try SourceScan.strippedSource(at: url)
            // A call spells the label; the declaration names its
            // parameter (`on display:`), so it is not counted.
            let calls =
                source.components(separatedBy: "showsPresentation(on:")
                .count - 1
            if calls > 0 { presentation[url.lastPathComponent] = calls }
        }
        #expect(
            presentation == ["KiwiCore+ScreenCovering.swift": 1],
            "presentation read beside the verdict: \(presentation)"
        )
        for file in [
            "Commands/SpaceSwitchCue.swift", "Commands/ModeCycleCue.swift",
            "Profiles/KiwiCore+DesktopCue.swift",
        ] {
            let source = try SourceScan.strippedSource(
                at: core.appendingPathComponent(file)
            )
            #expect(
                source.contains("!shelfStandsDown(on:"),
                "\(file) asks the stand-down"
            )
        }
    }
}
