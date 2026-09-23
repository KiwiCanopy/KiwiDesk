import Foundation
import Testing

@testable import KiwiDeskCore

/// Who may take a screen combination from a profile (#1530).
///
/// A claim strips other profiles' files, so it must happen only
/// at the doors the owner ruled: a save or create of the live
/// arrangement, a load, and the Profiles page's pick. Those doors
/// share one home, `KiwiCore+MonitorSetClaim.swift`, which is the
/// only Core file that may spell `profiles.claim(`. The negative
/// half is the point: a claim reached from boot or the
/// monitor-change matching would rewrite a user's hand-edited
/// profiles at start-up — so the doors' CALLERS are a census too,
/// since a door called from the wrong file strips just as well.
@Suite("A combination is claimed only at the ruled doors (#1530)")
struct MonitorSetClaimSeamTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    private let claimDoors =
        "Profiles/KiwiCore+MonitorSetClaim.swift"

    @Test("profiles.claim( is spelled only in the claim doors")
    func claimHasOneHome() throws {
        let root = coreRoot
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hits = source.occurrences(of: "profiles.claim(")
            guard hits > 0 else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            counts[key] = hits
        }
        let stray =
            "profiles.claim( is named outside the claim doors; a "
            + "claim rewrites other profiles, so only a save, a "
            + "load or the Profiles page's pick may take one — "
            + "never boot or monitor-change matching (#1530)"
        // The save tail's, and the load's and pick's shared
        // hand-over.
        #expect(counts == [claimDoors: 2], Comment(rawValue: stray))
    }

    /// Who may call a door that claims, per file over both trees,
    /// declarations included. A new caller registers here with
    /// its reason — and one on the boot or monitor-change path is
    /// the defect this suite exists for, not an entry.
    private let doorCallers: [String: [String: Int]] = [
        "loadProfile(named:": [
            // The `load_profile` arm, and the Profiles row's Load.
            "KiwiCore+Profiles.swift": 1,
            "ProfilesSection+RowActions.swift": 1,
        ],
        "claimMonitorSet(": [
            "KiwiCore+MonitorSetClaim.swift": 1,
            // The Profiles page's `+` pick.
            "SettingsModel+ScreenSetups.swift": 1,
        ],
        "persistProfile(": [
            // Declaration and the `save_profile` arm.
            "KiwiCore+Profiles.swift": 2,
            // The quick menu's Keep; the Settings Save.
            "AppDelegate.swift": 1,
            "SettingsModel+Profiles.swift": 1,
        ],
        "applyStandard(": [
            "KiwiCore+ProfileResolution.swift": 1,
            // Presets ▸ Apply.
            "SettingsModel+Profiles.swift": 1,
            // The one boot caller: the first-run Starter seed,
            // which runs only with no profile saved, so its claim
            // has no sibling to strip.
            "KiwiCore+StarterSeed.swift": 1,
        ],
    ]

    @Test("The claiming doors have a census of callers")
    func doorCallersAreCounted() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        let files = try SourceScan.swiftSources(under: root)
        #expect(!files.isEmpty)
        let sources = try files.map {
            (
                $0.lastPathComponent,
                SourceScan.stripComments(
                    try String(contentsOf: $0, encoding: .utf8)
                )
            )
        }
        for (door, allowed) in doorCallers {
            var counts: [String: Int] = [:]
            for (name, source) in sources {
                let hits = source.occurrences(of: door)
                if hits > 0 { counts[name] = hits }
            }
            #expect(
                counts == allowed,
                Comment(
                    rawValue:
                        "\(door) gained or lost a caller; a door "
                        + "that claims takes a monitor set from "
                        + "other profiles, so register the caller "
                        + "with its reason — never one on the boot "
                        + "or monitor-change path (#1530)"
                )
            )
        }
    }

    /// The save tail is `saveProfile`'s, so every activating write
    /// (Keep, Settings Save, `save_profile`, a create, a preset)
    /// claims through it rather than each caller remembering to.
    @Test("The one profile write door claims")
    func saveDoorClaims() throws {
        let file = coreRoot.appendingPathComponent(
            "Profiles/KiwiCore+ProfileSpaces.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        let open = try #require(
            source.range(of: "func saveProfile(_ profile: Profile)")
        )
        let body = source[open.upperBound...]
            .prefix(while: { $0 != "}" })
        #expect(!body.isEmpty)
        #expect(body.contains("claimLiveSet(heldBy: profile)"))
    }
}
