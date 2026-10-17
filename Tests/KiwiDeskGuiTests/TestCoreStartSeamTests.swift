import Foundation
import Testing

/// No test admits a test core's start (#2294): every write of
/// `BootRun.admitsStart` under `Tests/` sits in a file named
/// here and hands the gate a refusing closure, since one
/// `{ true }` boots a test core against the host.
///
/// Residue: the needle is the swift-format spelling
/// `admitsStart =`; a write spelled through a key path or a
/// helper is review's.
@Suite("Test core start seam (#2294)")
struct TestCoreStartSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let testTrees = SourceScan.targetTrees(
        under: root.appendingPathComponent("Tests")
    )

    /// Who may write the gate, and why.
    private static let allowed = [
        // The twin tripwires every `makeTestCore` core arms.
        "TestCoreTripwires.swift",
        // Drives the real reset with a silent refusal.
        "CrossSessionRestorePhaseTests.swift",
    ]

    @Test("only a refusing closure is written to the gate")
    func writesRefuse() throws {
        let sites = try Self.testTrees.flatMap {
            try SourceScan.identifierSites(
                // Split, or the scan finds its own needle.
                of: "admitsStart" + " =",
                under: $0
            )
        }
        // Non-vacuity: both twins and the restore test write it.
        let files = Set(sites.map(\.file.lastPathComponent))
        #expect(files == Set(Self.allowed))
        #expect(sites.count >= 3)
        for site in sites {
            let lines = try SourceScan.strippedSource(at: site.file)
                .split(separator: "\n", omittingEmptySubsequences: false)
            let body = lines[(site.line - 1)...]
                .prefix(4)
                .joined(separator: "\n")
            #expect(
                body.contains("false") && !body.contains("true"),
                "\(site.site) admits a test core's start"
            )
        }
    }
}
