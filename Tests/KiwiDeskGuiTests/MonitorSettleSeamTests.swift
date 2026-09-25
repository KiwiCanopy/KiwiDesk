import Foundation
import Testing

/// The #1612 settle's wiring no fixture reaches: a Space Bar draws
/// only on a real screen, so the bars' refresh at the report is
/// pinned here, beside the census of the doors that supersede a
/// pending settle (profiles.md ▸ "A screen-count change settles").
@Suite("Monitor settle seam (#1612)")
struct MonitorSettleSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    @Test("an owed settle refreshes the bars and takes the retile")
    func armRefreshesTheBars() throws {
        let text = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+Events.swift"
            )
        )
        let arm = try #require(
            SourceScan.declarationBody(
                after: "if monitorChangeSettles(priorCount:",
                in: text
            )
        )
        #expect(arm.contains("scheduleMonitorSettle()"))
        #expect(arm.contains("settleRetiles = true"))
        let owed = try #require(
            SourceScan.declarationBody(
                after: "if monitorSettlePending",
                in: arm
            )
        )
        #expect(owed.contains("updateBars()"))
        #expect(text.contains("&& !settleRetiles"))
    }

    @Test("the profile doors supersede a pending settle")
    func doorsSupersede() throws {
        var found: [String: Int] = [:]
        let prefix = Self.core.path + "/"
        for file in try SourceScan.swiftSources(under: Self.core) {
            let hits = try SourceScan.strippedSource(at: file)
                .occurrences(of: "supersedeMonitorSettle()")
            if hits > 0 {
                found[String(file.path.dropFirst(prefix.count))] = hits
            }
        }
        // The declaration spells it too (`func supersedeMonitorSettle()`).
        #expect(
            found == [
                "Profiles/KiwiCore+MonitorSettle.swift": 1,
                "Profiles/KiwiCore+ProfileResolution.swift": 2,
                "Profiles/KiwiCore+MonitorChange.swift": 1,
            ]
        )
    }
}
