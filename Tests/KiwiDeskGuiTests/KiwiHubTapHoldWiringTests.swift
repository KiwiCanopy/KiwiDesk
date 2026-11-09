import Foundation
import Testing

/// KiwiHub tells Core it holds the keyboard at its key and resign
/// key alone (#1229), so a modifier tap never fires while the
/// panel takes ⌘ for its own keys, and a closed panel never leaves
/// the taps held. Core's half is `KiwiHubHeldTapTests`.
@Suite("KiwiHub holds the taps while key (#1229)")
struct KiwiHubTapHoldWiringTests {
    private func body(_ function: String) throws -> String {
        try SourceScan.functionBody(
            of: function,
            in: "JumpPanelController.swift",
            under: "Jump",
            root: "Sources/KiwiDesk"
        )
    }

    @Test("key holds the taps, resign key lets them go")
    func panelKeyWiring() throws {
        #expect(
            try body("windowDidBecomeKey")
                .contains("core.setKiwiHubHoldsKeys(true)")
        )
        #expect(
            try body("windowDidResignKey")
                .contains("core.setKiwiHubHoldsKeys(false)")
        )
    }

    @Test("no other GUI file sets the hold")
    func oneHome() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let files = try SourceScan.swiftSources(
            under: root.appendingPathComponent("Sources/KiwiDesk")
        )
        #expect(!files.isEmpty)
        var sites: [String] = []
        for file in files {
            let source = try SourceScan.strippedSource(at: file)
            let count =
                source.components(separatedBy: "setKiwiHubHoldsKeys(")
                .count - 1
            sites += Array(repeating: file.lastPathComponent, count: count)
        }
        #expect(
            sites == [
                "JumpPanelController.swift", "JumpPanelController.swift",
            ]
        )
    }
}
