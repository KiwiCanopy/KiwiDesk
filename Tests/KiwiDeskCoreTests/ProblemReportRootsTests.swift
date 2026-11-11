import Foundation
import Testing

@testable import KiwiDeskCore

/// The exported log's header (#3214) reads the keep document, so
/// a root added there joins the header or is left out by name. A
/// root in neither set would be a live value a report never
/// shows.
@Suite("Problem report roots (#3214)")
@MainActor
struct ProblemReportRootsTests {
    @Test("every keep root is in the header or left out by name")
    func everyRootIsRuled() throws {
        let core = makeTestCore()
        guard case .object(let document) = core.keepDocument else {
            Issue.record("the keep document is no object")
            return
        }
        let roots = Set(document.keys)
        #expect(roots.count >= 7)
        let ruled = Set(KiwiCore.headerDefaults.keys)
            .union(KiwiCore.headerLeftOut)
            .union([KiwiCore.headerListed])
        #expect(roots == ruled)
        #expect(
            Set(KiwiCore.headerDefaults.keys)
                .isDisjoint(with: KiwiCore.headerLeftOut)
        )
    }

    @Test("a live value off its default reaches the header")
    func liveValuesReachTheHeader() throws {
        let core = makeTestCore()
        let before = core.changedSettingsLines
        #expect(!before.contains { $0.hasPrefix("/focus_wrap") })
        let wrap = try #require(
            FocusWrap.allCases.first { $0 != FocusWrap.defaultMode }
        )
        #expect(!before.contains { $0.hasPrefix("/space_modes") })
        core.focusWrap.base = wrap
        #expect(
            core.changedSettingsLines.contains(
                "/focus_wrap = \"\(wrap.rawValue)\""
            )
        )
    }
}
