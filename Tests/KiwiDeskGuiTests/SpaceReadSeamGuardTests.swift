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
/// reds as surely as a stray elsewhere. A needle matches the
/// QUALIFIED name with no identifier character after it, so a
/// point-free `.flatMap(NativeSpaces.displayUUID)` counts as a read
/// while `displayUUIDOverride` does not. Residue: `NativeSpaces`' own
/// unqualified uses (`mainDisplayUUID`, reached behind
/// `readDesktops`) and a read through another API for the same fact
/// are outside the scan; the stand-down's verdict body is held by
/// `ShownUserSpaceSeamTests`.
@Suite("Display-UUID and active-Space reads stay behind their seams")
struct SpaceReadSeamGuardTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    /// Files under Core spelling `needle`, with their counts; with
    /// `whole`, only where no identifier character follows it.
    private func sites(
        of needle: String,
        whole: Bool = false
    ) throws -> [String: Int] {
        let pattern =
            NSRegularExpression.escapedPattern(for: needle)
            + (whole ? "(?![A-Za-z0-9_])" : "")
        let regex = try NSRegularExpression(pattern: pattern)
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = try SourceScan.strippedSource(at: file)
            guard text.contains(needle) else { continue }
            let count = regex.numberOfMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            )
            if count > 0 { found[file.lastPathComponent] = count }
        }
        return found
    }

    @Test("the display-UUID read has its seam's default alone")
    func displayUUIDHasOneHome() throws {
        #expect(
            try sites(of: "NativeSpaces.displayUUID", whole: true)
                == ["DesktopMemory.swift": 1]
        )
    }

    @Test("the active-Space read has its seam's default alone")
    func activeSpaceIsUserHasOneHome() throws {
        #expect(
            try sites(of: "NativeSpaces.activeSpaceIsUser", whole: true)
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
            // Whitespace-free, so a reflow keeps the pin readable.
            let squeezed = source.filter { !$0.isWhitespace }
            #expect(
                squeezed.contains(
                    "core.desktopMemory.readActiveSpaceIsUser={"
                        + "statesNoTopology"
                        + "&&NativeSpaces.activeSpaceIsUserOverride==nil"
                        + "?true"
                ),
                "\(twin) misses the active-Space pin"
            )
        }
    }
}
