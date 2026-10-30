import Foundation
import Testing

/// Who arms the pass an explicit apply owes (#2785): `retile`, for
/// the pass it runs, and the body's own re-arm, nowhere else. The
/// arm must read the pass that RUNS, since a held apply is paid by
/// a later plain `retile()` the motion gate merged it into (#804).
/// The behavioural half is `ApplyHealPassTests`.
@Suite("Apply heal pass needle (#2785)")
struct ApplyHealPassNeedleTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    @Test("Only retile and the body's re-arm arm the pass")
    func armSitesAreCensused() throws {
        var sites: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: Self.core) {
            let source = Array(
                SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
            )
            let calls = SourceScan.callSites(
                in: source,
                for: "oweApplyHealPass"
            ).count
            if calls > 0 { sites[file.lastPathComponent] = calls }
        }
        // The re-arm and the declaration in the pass's own file.
        #expect(
            sites == [
                "KiwiCore+Retile.swift": 1,
                "KiwiCore+ApplyHealPass.swift": 2,
            ]
        )
    }

    @Test("retile arms on the pass that runs")
    func armReadsTheRunningPass() throws {
        let retile = try SourceScan.functionBody(
            of: "retile",
            in: "KiwiCore+Retile.swift",
            under: "App"
        )
        #expect(retile.contains("let pass = run.pass"))
        #expect(retile.contains("if pass.probes { oweApplyHealPass() }"))
    }
}
