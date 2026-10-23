import Foundation
import Testing

/// Every Space switch or follow that can move focus onto another
/// screen hands the pointer over through `warpForSwitch` (#2548):
/// `switchSpace`, `followSwitch`, `handFollowFocus` and the AX focus
/// follow's landing. This registers the known callers: a call lost,
/// moved between files or doubled inside one reds. A NEW door that
/// warps through `focusWindow` and never names the seam is outside
/// the scan — review's. Counted per file, the definition included.
@Suite("Screen handoff callers (#2548)")
struct ScreenHandoffSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static let callers: [String: Int] = [
        // The definition.
        "KiwiCore+ScreenHandoff.swift": 1,
        "KiwiCore+SpaceSwitch.swift": 1,
        // `followSwitch` and `handFollowFocus`.
        "KiwiCore+DisplayFocus.swift": 2,
        // The AX focus follow's landing (⌘Tab onto another screen).
        "KiwiCore+SpaceCommands.swift": 1,
    ]

    @Test("the handoff has its four doors and no other")
    func callersAreRegistered() throws {
        let sites = try SourceScan.identifierSites(
            of: "warpForSwitch(",
            under: Self.root.appendingPathComponent("Sources/KiwiDeskCore")
        )
        #expect(!sites.isEmpty)
        var counts: [String: Int] = [:]
        for site in sites {
            counts[site.file.lastPathComponent, default: 0] += 1
        }
        #expect(counts == Self.callers)
    }
}
