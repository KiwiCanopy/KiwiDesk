import Foundation
import Testing

/// **Only the layout loop records asks** (#1694): the size-bound
/// learner's `recordAsk` is reached from one engine method, and
/// that method from `retile`'s layout loop alone. A stash park or
/// a float restore calling either would open an ask the learner
/// then reads as the app refusing a layout frame.
@Suite("Layout ask seam (#1694)")
struct LayoutAskSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    @Test("recordAsk is called from the layout turn alone")
    func recordAskHasOneCaller() throws {
        let sites = try SourceScan.identifierSites(
            of: "boundLearner.recordAsk(",
            under: Self.core
        )
        #expect(
            sites.map(\.file.lastPathComponent)
                == ["TilingEngine+Issue.swift"],
            "found \(sites.map(\.site))"
        )
    }

    @Test("the layout turn is called from retile alone")
    func layoutTurnHasOneCaller() throws {
        let sites = try SourceScan.identifierSites(
            of: "issueLayoutFrame(",
            under: Self.core
        )
        // The definition and the one call, by file: a second
        // caller anywhere adds a site.
        #expect(
            sites.map(\.file.lastPathComponent).sorted()
                == ["TilingEngine+Issue.swift", "TilingEngine.swift"],
            "found \(sites.map(\.site))"
        )
    }
}
