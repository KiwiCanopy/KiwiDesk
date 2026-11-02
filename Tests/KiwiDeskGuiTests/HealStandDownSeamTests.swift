import Foundation
import Testing

/// The #2907 wirings no fixture reaches alone: each per-Space
/// session heal asks the one stand-down gate, the gate reads the
/// compositor through the raise gate's seam, and the boot census
/// resumes a carried filing as its departure.
@Suite("Heals and the boot seed take the #2907 doors")
struct HealStandDownSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    private func source(_ path: String) throws -> String {
        let text = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(path)
        )
        try #require(!text.isEmpty)
        return text
    }

    @Test("each per-Space session heal asks the gate once")
    func healsAskTheGate() throws {
        for file in [
            "Commands/KiwiCore+SplitFloorHeal.swift",
            "Commands/KiwiCore+WeightHeal.swift",
        ] {
            #expect(
                try source(file).occurrences(of: "healStandsDown(for:") == 1,
                .init(rawValue: file)
            )
        }
    }

    @Test("the gate reads the shown-Desktop seam, never the raw read")
    func gateReadsTheSeam() throws {
        let gate = try source("Commands/KiwiCore+HealStandDown.swift")
        #expect(gate.contains("windowIsOnShownDesktop("))
        #expect(gate.contains("lastDesktopSwitch"))
        #expect(!gate.contains("NativeSpaces."))
    }

    @Test("the boot census resumes a carried filing")
    func seedResumesCarriedFilings() throws {
        let seed = try source("App/KiwiCore+AwayWindows.swift")
        #expect(seed.occurrences(of: "resumeCarriedDeparture(") == 1)
    }
}
