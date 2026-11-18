import Foundation
import Testing

/// The display-UUID and active-Space reads stay behind their
/// `DesktopMemory` seams (#3442): live, each is a WindowServer
/// round trip on every bar refresh, ring sync and stand-down, and
/// the main-actor suites queued behind them. Both `makeTestCore`
/// twins pin them, so a Core site reading either directly runs
/// live in every fixture again.
///
/// Counted PER FILE, the `MouseButtonSeamGuardTests` shape: each
/// home holds exactly one read, so a second read grown inside it
/// reds as surely as a stray elsewhere. Residue: the needles spell
/// the QUALIFIED call, so `NativeSpaces`' own unqualified uses
/// (`mainDisplayUUID`, reached behind `readDesktops`) and a read
/// through another API for the same fact are outside the scan.
@Suite("Display-UUID and active-Space reads stay behind their seams")
struct SpaceReadSeamGuardTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

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

    @Test("the display-UUID read has its seam's default alone")
    func displayUUIDHasOneHome() throws {
        #expect(
            try sites(of: "NativeSpaces.displayUUID(")
                == ["DesktopMemory.swift": 1]
        )
        // The stand-down's verdict takes the seam's answer rather
        // than reading it inside `NativeSpaces`.
        #expect(
            try sites(of: "uuid: desktopMemory.readDisplayUUID(display)")
                == ["KiwiCore+ScreenCovering.swift": 1]
        )
    }

    @Test("the active-Space read has its seam's default alone")
    func activeSpaceIsUserHasOneHome() throws {
        #expect(
            try sites(of: "NativeSpaces.activeSpaceIsUser")
                == ["DesktopMemory.swift": 1]
        )
        #expect(
            try sites(of: "desktopMemory.readActiveSpaceIsUser()")
                == [
                    "KiwiCore+AppBar.swift": 1,
                    "KiwiCore+DesktopSettle.swift": 1,
                ]
        )
    }

    /// A deletion from BOTH twins is otherwise silent: the
    /// twins-identical scan sees only a one-sided one.
    @Test("makeTestCore pins both reads")
    func testCorePinsBothReads() throws {
        for twin in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let source = try SourceScan.strippedSource(
                at: Self.root.appendingPathComponent(
                    "Tests/\(twin)/TestCoreDesktopPins.swift"
                )
            )
            #expect(
                source.contains(
                    "core.desktopMemory.readDisplayUUID = { display in"
                ),
                "\(twin) misses the display-UUID pin"
            )
            #expect(
                source.contains(
                    "if let known = testDisplayUUIDs[display]"
                ),
                "\(twin) reads the display UUID live"
            )
            #expect(
                source.contains(
                    "core.desktopMemory.readActiveSpaceIsUser = {\n"
                        + "        statesNoTopology"
                ),
                "\(twin) misses the active-Space pin"
            )
        }
    }
}
