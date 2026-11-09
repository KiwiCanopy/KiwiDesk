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
        // Ahead of the bound-profile arm, whose load returns early.
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "Profiles/KiwiCore+MonitorChange.swift"
            )
        )
        let filing = try #require(
            source.range(of: "desktopMemory.fileShownUserSpaces(desktops)")
        )
        let binding = try #require(
            source.range(of: "mainDesktopBinding(in: desktops)")
        )
        #expect(filing.lowerBound < binding.lowerBound)
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

    @Test("the stand-down and the shown-Desktop resolver read the verdict")
    func standDownReads() throws {
        #expect(
            try sites(of: "filed: desktopMemory.shownUserSpaces") == [
                "KiwiCore+ScreenCovering.swift": 1,
                // A full-screen screen names no Desktop: the flip
                // refuses and the sizes take the shared entry
                // (#2771, #2921).
                "KiwiCore+ShownDesktop.swift": 1,
            ]
        )
    }

    /// The stand-down's live read goes through the one seam both test
    /// cores pin (#2937): a host's own full-screen Space stood the
    /// pocket suites down on the owner's Mac. The read lives in the
    /// one `screenShowsUserSpace`, which the stand-down and the
    /// screen moves (#3117) both ask.
    @Test("the stand-down's live Space read is a pinned seam")
    func liveReadIsPinned() throws {
        let covering = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+ScreenCovering.swift"
            )
        )
        let verdict = try #require(
            SourceScan.declarationBody(
                after: "func screenShowsUserSpace(_ display: DisplayID)",
                in: covering
            )
        )
        #expect(
            verdict.occurrences(of: "live: desktopMemory.liveSpaceIsUser")
                == 1
        )
        let standDown = try #require(
            SourceScan.declarationBody(
                after: "func overlaysStandDown(on display: DisplayID)",
                in: covering
            )
        )
        #expect(
            standDown.occurrences(of: "screenShowsUserSpace(display)")
                == 1
        )
        #expect(
            try sites(of: "NativeSpaces.currentSpaceIsUser(")
                == ["KiwiCore+ScreenCovering.swift": 1]
        )
        #expect(
            try sites(of: "NativeSpaces.liveSpaceIsUser")
                == ["DesktopMemory.swift": 1]
        )
        let tests = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Tests")
        for twin in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let source = try SourceScan.strippedSource(
                at: tests.appendingPathComponent(
                    "\(twin)/TestCoreDesktopPins.swift"
                )
            )
            #expect(
                source.contains(
                    "core.desktopMemory.liveSpaceIsUser = { _ in true }"
                ),
                "\(twin)"
            )
            // The filed half: the reading every verdict is filed
            // from answers no reading unless a suite states a
            // topology override.
            #expect(
                source.contains(
                    "core.desktopMemory.readDesktops = {\n"
                        + "        statesNoTopology\n"
                        + "            ? DesktopSnapshot("
                ),
                "\(twin)"
            )
            let factory = try SourceScan.strippedSource(
                at: tests.appendingPathComponent("\(twin)/TestCore.swift")
            )
            #expect(factory.contains("pinDesktopReads(core)"), "\(twin)")
        }
        // Every `desktopSnapshot` read in Core goes through the
        // seam, its default the one left; `activeDesktopNumber()`,
        // which reads it unqualified, is outside this needle.
        #expect(
            try sites(of: "NativeSpaces.desktopSnapshot")
                == ["DesktopMemory.swift": 1]
        )
        #expect(
            try sites(of: "desktopMemory.readDesktops()")[
                "KiwiCore+DesktopIdentity.swift"
            ] == 1
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
