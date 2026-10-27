import Foundation
import Testing

/// The shelf's stand-down verdict is filed where the Desktop
/// reading is taken and read where the shelf decides (#2667): no
/// Core suite drives the live switch handler or the host's
/// screens, so the three wirings are needled.
@Suite("Shown user-Space seam")
struct ShownUserSpaceSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// Files under Core spelling `needle`, with their counts.
    private func sites(of needle: String) throws -> [String: Int] {
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = try SourceScan.strippedSource(at: file)
            let count = text.occurrences(of: needle)
            if count > 0 { found[file.lastPathComponent] = count }
        }
        return found
    }

    @Test("the switch handler files the verdict ahead of its bars")
    func switchFiles() throws {
        #expect(
            try sites(of: "desktopMemory.fileShown(snapshot)")
                == ["KiwiCore+Desktops.swift": 1]
        )
        #expect(
            try sites(of: "shownSpaces =") == ["DesktopMemory.swift": 1]
        )
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "Profiles/KiwiCore+Desktops.swift"
            )
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "func handleDesktopChange()",
                in: source
            )
        )
        let filing = try #require(
            body.range(of: "desktopMemory.fileShown(snapshot)")
        )
        for later in ["updateBars(", "retile("] {
            let first = try #require(body.range(of: later), "\(later)")
            #expect(filing.lowerBound < first.lowerBound, "\(later)")
        }
    }

    @Test("a monitor change refiles the verdict from its reading")
    func monitorChangeFiles() throws {
        #expect(
            try sites(of: "desktopMemory.fileShownUserSpaces(desktops)")
                == ["KiwiCore+MonitorChange.swift": 1]
        )
    }

    @Test("the live read is handed the filed verdict")
    func readForwardsTheVerdict() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent("OS/NativeSpaces.swift")
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "public static func currentSpaceIsUser(\n"
                    + "        display: DisplayID,",
                in: source
            )
        )
        #expect(body.occurrences(of: "filed: filed") == 1)
    }

    @Test("the stand-down reads the filed verdict")
    func standDownReads() throws {
        #expect(
            try sites(of: "filed: desktopMemory.shownUserSpaces")
                == ["KiwiCore+ScreenCovering.swift": 1]
        )
    }

    @Test("only the reading and a display change write the verdict")
    func writersAreRuled() throws {
        #expect(
            try sites(of: "shownUserSpaces =") == [
                "DesktopMemory.swift": 1, "KiwiCore+Events.swift": 1,
            ]
        )
    }
}
