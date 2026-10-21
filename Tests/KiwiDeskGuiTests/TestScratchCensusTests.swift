import Foundation
import Testing

/// Every scratch folder and defaults domain a test makes comes
/// from `TestScratch.swift`, which removes them (#2518), and
/// every inline Python source is written by `runPythonSource`
/// into a directory holding only it.
///
/// Matched on each file with comments stripped and ALL
/// whitespace removed, so a call swift format splits across
/// lines (`UserDefaults(` / `suiteName:`) is still one needle.
/// That trades the identifier boundary away: a needle also hits
/// inside a longer name, which is why each one is a full spelling
/// rather than a stem. Needles are spelled in pieces so this file
/// never matches its own scan.
@Suite("Test scratch stays in its one home")
struct TestScratchCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let testTrees = SourceScan.targetTrees(
        under: root.appendingPathComponent("Tests")
    )
    private static let home = "TestScratch.swift"

    struct Needle: CustomTestStringConvertible, Sendable {
        let text: String
        /// Files that may spell it; `home` must, in both twins.
        let allowed: Set<String>
        var testDescription: String { text }
    }

    static let needles: [Needle] = [
        Needle(text: "temporary" + "Directory", allowed: []),
        Needle(text: "NSTemporary" + "Directory", allowed: [home]),
        Needle(text: "UserDefaults(" + "suiteName", allowed: [home]),
        Needle(text: "UserDefaults.init(" + "suiteName", allowed: []),
        Needle(text: "itemReplacement" + "Directory", allowed: []),
        Needle(text: "mkd" + "temp", allowed: []),
        Needle(text: "mks" + "temp", allowed: []),
        // The spawn primitives point children at the run's root.
        Needle(
            text: "TMP" + "DIR",
            allowed: ["ScriptFixture.swift", "GuiScriptFixture.swift"]
        ),
        Needle(text: "\"/" + "tmp", allowed: Self.literalTmp),
        // A minted script name, beside other files.
        Needle(text: ")" + ".py\"", allowed: []),
        Needle(text: "PathExtension(\"" + "py\")", allowed: []),
    ]

    /// `/tmp` spelled out, each with its reason: a socket root
    /// short enough for `sun_path`'s 104 bytes, removed by its own
    /// `defer`, or a path string nothing creates.
    static let literalTmp: Set<String> = [
        "CoreInitPathTests.swift",  // sun_path root; a probe string
        "MachineLocationLegacyTests.swift",  // sun_path root
        "SocketServerOwnershipTests.swift",  // over-long, never made
        "AISetupPromptTests.swift",  // a path string only
        "LogExportTextTests.swift",  // a path string only
        "SecondLaunchExitTests.swift",  // a path string only
    ]

    private static func collapsedSources() throws -> [(URL, String)] {
        try testTrees.flatMap { tree in
            try SourceScan.swiftSources(under: tree).map { file in
                let source = try SourceScan.strippedSource(at: file)
                return (file, source.filter { !$0.isWhitespace })
            }
        }
    }

    @Test("scratch spellings stay in their homes", arguments: needles)
    func confined(needle: Needle) throws {
        let sources = try Self.collapsedSources()
        // A gutted walk would pass every clause below.
        #expect(sources.count > 500)
        let hits = sources.filter { $0.1.contains(needle.text) }
            .map(\.0)
        if needle.allowed.contains(Self.home) {
            let homes = hits.filter { $0.lastPathComponent == Self.home }
            #expect(homes.count == 2, "\(needle.text) gone from a twin")
        }
        let strays = hits.map(\.lastPathComponent)
            .filter { !needle.allowed.contains($0) }
        #expect(
            strays.isEmpty,
            "\(needle.text) outside its homes: \(strays.sorted())"
        )
    }
}
