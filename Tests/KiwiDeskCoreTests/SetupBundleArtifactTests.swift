import Foundation
import Testing

@testable import KiwiDeskCore

/// The direction no other guard can see: an artifact that never
/// joined the backup (#606).
///
/// `SetupBundleTests.theAllowListIsPinned` asserts the written
/// file's top-level keys, so a field ADDED to the bundle has to
/// argue for itself. The opposite — a new store under
/// `~/.config/KiwiDesk` that nobody adds — is invisible to every
/// guard in the tree, and its symptom is a user moving Macs and
/// silently losing whatever it held. `palettes.json` nearly was
/// that symptom: applying a palette writes its colours into
/// `gui.json`, so the current *look* travelled while the saved
/// *library* would have been left behind.
///
/// `ConfigArtifact` is the register, and this suite is what makes
/// adding a case to it unavoidable rather than polite.
@Suite("Every config artifact answers the backup question (#606)")
@MainActor
struct SetupBundleArtifactTests {
    @Test("Every artifact has a URL, and they are distinct")
    func everyArtifactResolves() {
        let core = makeTestCore()
        let urls = ConfigArtifact.allCases.map(core.url(of:))
        #expect(urls.count == ConfigArtifact.allCases.count)
        // Two artifacts sharing a path would mean one silently
        // stands in for the other in every discard and every
        // backup.
        #expect(Set(urls.map(\.path)).count == urls.count)
        for url in urls {
            #expect(
                url.path.hasPrefix(core.configDirectory.path),
                "an artifact outside the config directory"
            )
        }
    }

    /// The load-bearing one: what the register says travels is
    /// what the bundle actually carries.
    ///
    /// Written as a mapping rather than a count, so adding a case
    /// reds here with the case's own name rather than with an
    /// arithmetic mismatch a reader has to decode.
    @Test("What the register says travels is what a bundle holds")
    func travellingArtifactsAreInTheBundle() throws {
        let core = makeTestCore()
        // Give every artifact something to carry, so an absence in
        // the bundle means the bundle does not carry that KIND
        // rather than that this install had none of it.
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        try core.guiConfigStore.save(config)
        try core.profiles.save(
            Profile(
                name: "Desk",
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaces: [SpaceID("1")],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        try core.paletteLibrary.save(
            ColorPalette(
                name: "Mine",
                colors: [ColorPaletteKeys.all[0]: "#112233"]
            )
        )

        let bundle = try core.exportSetup()
        // Assert the loop has something to walk: every artifact
        // travels today, so a `where` that matched nothing would
        // be a green having checked nothing — the vacuity a
        // prover round already caught two suites over.
        #expect(
            ConfigArtifact.allCases.contains {
                $0.travelsInABackup
            }
        )
        for artifact in ConfigArtifact.allCases
        where artifact.travelsInABackup {
            let carried: Bool =
                switch artifact {
                case .guiConfig: bundle.config != nil
                case .profiles: !bundle.profiles.isEmpty
                case .palettes: !bundle.palettes.isEmpty
                }
            #expect(
                carried,
                Comment(
                    rawValue:
                        "`ConfigArtifact.\(artifact)` says it "
                        + "travels in a backup, and the exported "
                        + "bundle does not carry it. A new "
                        + "artifact owes both the case and its "
                        + "line in `exportSetup` / `restoreSetup` "
                        + "— nothing else in the tree can see the "
                        + "omission, and its symptom is a user "
                        + "losing it on a new Mac."
                )
            )
        }
    }

    /// Vacuous today, deliberately and statedly: nothing answers
    /// `travelsInABackup == false`, so the loop walks nothing. It
    /// is kept as the standing check on a future exclusion rather
    /// than deleted, and says so instead of implying coverage.
    ///
    /// Also stated, since it is the direction this cannot see: an
    /// artifact flipped to `false` **with** a reason passes here
    /// while `exportSetup` still carries it —
    /// `travellingArtifactsAreInTheBundle` is what would have to
    /// grow the inverse arm if an exclusion ever lands.
    @Test("An artifact left behind says why")
    func exclusionsCarryTheirReason() {
        for artifact in ConfigArtifact.allCases
        where !artifact.travelsInABackup {
            #expect(
                artifact.leftBehindBecause?.isEmpty == false,
                Comment(
                    rawValue:
                        "`ConfigArtifact.\(artifact)` stays behind "
                        + "and says nothing about why — an "
                        + "exclusion has to be a decision on "
                        + "record, not an omission"
                )
            )
        }
    }

    /// The register against the directory, as far as a test can
    /// reach.
    ///
    /// Stated residue rather than a claim of coverage: nothing can
    /// enumerate the files a FUTURE store will write, so this
    /// cannot catch the case it most wants to. What it does catch
    /// is a live install growing a config file that no artifact
    /// names — which is the same defect one step later, and the
    /// step a developer's own machine reaches first.
    @Test("A live config directory holds nothing unaccounted for")
    func liveDirectoryIsAccountedFor() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.paletteLibrary.save(
            ColorPalette(name: "Mine", colors: [:])
        )
        let known =
            Set(
                ConfigArtifact.allCases.map {
                    core.url(of: $0).lastPathComponent
                }
            )
            // Not artifacts, and each excluded for a stated reason:
            // runtime plumbing and the machine-specific snapshots
            // `SetupBundle`'s doc comment already argues about.
            .union([
                "init.lua", "KiwiDesk.sock", "KiwiDesk.lock",
                ".state_snapshot", ".session_snapshot",
            ])
        let present = try FileManager.default
            .contentsOfDirectory(
                atPath: core.configDirectory.path
            )
        for name in present {
            #expect(
                known.contains(name),
                Comment(
                    rawValue:
                        "`\(name)` appeared in the config "
                        + "directory and no `ConfigArtifact` "
                        + "names it. Does it travel in a backup? "
                        + "Answer it in the register."
                )
            )
        }
    }
}
