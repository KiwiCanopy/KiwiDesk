import Foundation
import Testing

/// The #2907 wirings no fixture reaches alone: each per-Space
/// session heal asks the one stand-down gate, the gate reads the
/// compositor through its pinned seam, and the boot census
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
        #expect(gate.contains("desktopMemory.readOffShown("))
        #expect(gate.contains("lastDesktopSwitch"))
        #expect(!gate.contains("NativeSpaces."))
    }

    /// The batch read defaults live, so it has one home and every
    /// test core pins it, in both twins.
    @Test("the batch read has one home and both twins pin it")
    func batchReadIsPinned() throws {
        let sites = try SourceScan.identifierSites(
            of: "NativeSpaces.anyOffShownDesktop",
            under: Self.core
        )
        #expect(sites.map(\.file.lastPathComponent) == ["DesktopMemory.swift"])
        let tests = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Tests")
        for twin in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let source = try SourceScan.strippedSource(
                at: tests.appendingPathComponent(
                    "\(twin)/TestCoreDesktopPins.swift"
                )
            )
            #expect(
                source.contains("readOffShown = { _ in false }"),
                .init(rawValue: twin)
            )
        }
    }

    /// Both boot arms admit through the one `admitBootAway`, which
    /// resumes a carried filing (#2907, #2949).
    @Test("the boot census resumes a carried filing")
    func seedResumesCarriedFilings() throws {
        let admit = try source("App/KiwiCore+AwayBootSeed.swift")
        #expect(admit.occurrences(of: "resumeCarriedDeparture(") == 1)
        #expect(admit.occurrences(of: "admitBootAway(") == 2)
        let desktops = try source("App/KiwiCore+AwayWindows.swift")
        #expect(desktops.occurrences(of: "admitBootAway(") == 1)
        // The gone handler's `recordAwayWindow` is the one other
        // filing; the boot seed writes none beside the admission.
        #expect(desktops.occurrences(of: "state.awayWindows[id] =") == 1)
    }
}
