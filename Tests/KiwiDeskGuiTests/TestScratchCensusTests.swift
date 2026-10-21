import Foundation
import Testing

/// Every scratch file and defaults domain a test makes goes
/// through `TestScratch.swift`, which removes them at the run's
/// exit and sweeps a dead run's at the next one (#2518). A test
/// reading the user temp dir or minting its own defaults suite
/// leaves litter on every run — 1.3 M temp entries and 113 k
/// plists had piled up, and a Python spawn listing the temp dir
/// took 15 s. Python sources are written by `ScriptFixture`'s
/// `runPythonSource` alone, into a directory holding only them.
///
/// Needles are spelled in pieces so this file never matches its
/// own scan.
@Suite("Test scratch stays in its one home")
struct TestScratchCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let testTrees = SourceScan.targetTrees(
        under: root.appendingPathComponent("Tests")
    )
    private static let home = "TestScratch.swift"

    @Test(
        "temp dirs and scratch defaults only through TestScratch",
        arguments: [
            "temporary" + "Directory",
            "NSTemporary" + "Directory",
            "UserDefaults(" + "suiteName",
        ]
    )
    func confinedToHome(needle: String) throws {
        let sites = try Self.testTrees.flatMap {
            try SourceScan.identifierSites(of: needle, under: $0)
        }
        // Both twins reach the machine through the last two
        // needles, so an empty scan is a broken walk, never a pass.
        let homes = Set(
            sites.filter { $0.file.lastPathComponent == Self.home }
                .map(\.file)
        )
        if !needle.hasPrefix("temporary") {
            #expect(homes.count == 2, "\(needle) gone from the twins")
        }
        let strays = sites.filter {
            $0.file.lastPathComponent != Self.home
        }
        #expect(
            strays.isEmpty,
            """
            \(needle) outside \(Self.home): \
            \(strays.map(\.site).joined(separator: ", "))
            """
        )
    }

    /// A minted script name — an interpolation followed by the
    /// extension — is a script written beside other files.
    @Test("python sources are written by runPythonSource alone")
    func pythonSourcesConfined() throws {
        let needle = ")" + ".py" + "\""
        var strays: [String] = []
        for tree in Self.testTrees {
            for file in try SourceScan.swiftSources(under: tree) {
                let source = try SourceScan.strippedSource(at: file)
                if source.contains(needle) {
                    strays.append(file.lastPathComponent)
                }
            }
        }
        #expect(strays.isEmpty, "minted .py outside: \(strays)")
    }
}
