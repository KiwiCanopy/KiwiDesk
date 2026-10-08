import Foundation
import Testing

/// An arrangement WRITE reads `capturedSpaces`, never the full live
/// list, so no Keep, Save, sidecar or partitioning record captures
/// a held Space (#1507 ruling 5, profiles.md) or a temporary one
/// (#1790). Scoped to where
/// arrangement writes live — Core's `Profiles/`, the GUI config
/// seam and the Settings model — every other reader of the live
/// list there is listed with its reason, and an unlisted one reds.
@Suite("Captured Spaces census (#1507)")
struct CapturedSpacesCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources")

    /// File → (reads of `workspaces.allSpaces`, why it may).
    private static let fullListReaders: [String: (Int, String)] = [
        "KiwiDeskCore/Profiles/KiwiCore+DesktopSpaces.swift":
            (1, "a Desktop return picks a Space; writes nothing"),
        "KiwiDeskCore/Profiles/KiwiCore+StarterRescale.swift":
            (1, "the ⌃⌥N top-up reaches a held Space by ruling"),
        "KiwiDeskCore/Profiles/KiwiCore+EmptyDisplayHeal.swift":
            (1, "the orphan's drop target; its number is minted"),
        "KiwiDeskCore/Profiles/KiwiCore+ProfileResolution.swift":
            (1, "the mode loop skips held and temporary Spaces"),
        "KiwiDeskCore/Profiles/KiwiCore+SpacePrune.swift":
            (1, "the prune; its callers keep held and temporary"),
        "KiwiDeskCore/Profiles/KiwiCore+HeldSpaces.swift":
            (5, "the held machinery itself"),
        "KiwiDeskCore/Profiles/KiwiCore+HeldSpaceReads.swift":
            (1, "`capturedSpaces` itself, the filtered view"),
        "KiwiDeskCore/Profiles/KiwiCore+HeldSpaceOrder.swift":
            (1, "the held batch's bar placement; captures nothing"),
        "KiwiDeskCore/Profiles/KiwiCore+HeldSpaceBoot.swift":
            (1, "boot's renumber takes every live number (#1646)"),
        "KiwiDeskCore/Profiles/KiwiCore+SpaceDisplays.swift":
            (4, "the resolve and the unplaced net place held too"),
        "KiwiDeskCore/Profiles/KiwiCore+ProfileSpaces.swift":
            (1, "the restore's focus snapshot"),
        "KiwiDeskCore/Profiles/KiwiCore+TemporarySpaces.swift":
            (3, "the temporary machinery itself (#1790)"),
        "KiwiDeskCore/Profiles/KiwiCore+SpaceProfileScope.swift":
            (1, "an added Space's place in live order (#1790)"),
        "KiwiDeskCore/App/KiwiCore+GuiConfig.swift":
            (1, "the Save's mode loop, which skips held"),
        "KiwiDesk/Settings/SettingsModel+Globals.swift":
            (1, "the boot-default probe, a read"),
    ]

    /// The capture sites, each reading the captured view.
    private static let captureSites: [String] = [
        "KiwiDeskCore/Profiles/KiwiCore+Profiles.swift",
        "KiwiDeskCore/Profiles/KiwiCore+ProfileSpaces.swift",
        "KiwiDeskCore/App/KiwiCore+GuiSpaces.swift",
        "KiwiDeskCore/App/KiwiCore+GuiConfigSeed.swift",
        "KiwiDesk/Settings/SettingsModel+Profiles.swift",
    ]

    private func scannedFiles() throws -> [URL] {
        let core = Self.root.appendingPathComponent("KiwiDeskCore")
        let profiles = try SourceScan.swiftSources(
            under: core.appendingPathComponent("Profiles")
        )
        let gui = try SourceScan.swiftSources(
            under: core.appendingPathComponent("App")
        ).filter { $0.lastPathComponent.hasPrefix("KiwiCore+Gui") }
        let settings = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent("KiwiDesk/Settings")
        )
        let files = profiles + gui + settings
        #expect(!profiles.isEmpty && !gui.isEmpty && !settings.isEmpty)
        return files
    }

    private func key(_ file: URL) -> String {
        String(file.path.dropFirst(Self.root.path.count + 1))
    }

    @Test("every reader of the full live list is listed with its reason")
    func fullListReadersAreListed() throws {
        var found: [String: Int] = [:]
        for file in try scannedFiles() {
            let hits = try SourceScan.strippedSource(at: file)
                .occurrences(of: "workspaces.allSpaces")
            if hits > 0 { found[key(file)] = hits }
        }
        #expect(found == Self.fullListReaders.mapValues(\.0))
    }

    @Test("every capture site reads the captured view")
    func captureSitesReadCaptured() throws {
        for site in Self.captureSites {
            let text = try SourceScan.strippedSource(
                at: Self.root.appendingPathComponent(site)
            )
            #expect(
                text.contains("capturedSpaces"),
                .init(rawValue: "\(site) no longer reads capturedSpaces")
            )
        }
    }
}
