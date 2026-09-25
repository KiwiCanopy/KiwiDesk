import Foundation
import Testing

/// An arrangement WRITE reads `capturedSpaces`, never the full live
/// list, so no Keep, Save, sidecar or partitioning record captures
/// a held Space (#1507 ruling 5, profiles.md). Scoped to where
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
            (2, "the heal's next number and the orphan's drop target"),
        "KiwiDeskCore/Profiles/KiwiCore+ProfileResolution.swift":
            (2, "the mode loop skips held; the prune keeps them"),
        "KiwiDeskCore/Profiles/KiwiCore+HeldSpaces.swift":
            (6, "the held machinery itself"),
        "KiwiDeskCore/Profiles/KiwiCore+SpaceDisplays.swift":
            (3, "the display resolve places held Spaces too"),
        "KiwiDeskCore/Profiles/KiwiCore+ProfileSpaces.swift":
            (1, "the restore's focus snapshot"),
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
