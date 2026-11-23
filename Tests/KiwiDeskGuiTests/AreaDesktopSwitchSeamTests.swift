import Foundation
import Testing

/// Both Desktop-switch arms switch every area of their screen
/// (#3517 ruling 17), and the live memory follows a merge at the
/// one split feed (ruling 22). The main arm is reached only through
/// `handleDesktopChange`, whose retile needs a host screen, so the
/// behaviour suite (`AreaDesktopMemoryTests`) drives the doors and
/// this suite pins that each arm calls them — each needle by exact
/// count and to its file, since zero is the defect and a second
/// call files or shows twice. The main departure's needle is
/// `ReturningFocusSeamTests`', which also files its sticky debt.
@Suite("Desktop switch area doors stay wired (#3517)")
struct AreaDesktopSwitchSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    private static let wirings: [(String, String)] = [
        (
            "activateArriving(target, on: key, in: snapshot)",
            "KiwiCore+Desktops.swift"
        ),
        (
            "rememberLeaving(display, leaving: leaving)",
            "KiwiCore+DesktopSpaces.swift"
        ),
        (
            "showArriving(target, on: display, as: arriving, in: snapshot)",
            "KiwiCore+DesktopSpaces.swift"
        ),
        (
            "remapAreaSpaces(from: state.workspaces.areaSplits, to: splits)",
            "KiwiCore+ScreenAreas.swift"
        ),
    ]

    @Test("each arm calls its area doors once, in its own file")
    func doorsAreWired() throws {
        for (needle, file) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            #expect(sites.count == 1, "`\(needle)`: \(sites.count)")
            #expect(
                sites.allSatisfy { $0.file.lastPathComponent == file },
                "`\(needle)` belongs in \(file)"
            )
        }
    }
}
