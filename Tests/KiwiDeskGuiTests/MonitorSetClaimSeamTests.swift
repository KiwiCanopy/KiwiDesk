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
/// half is the point: boot and the monitor-change matching reach
/// Core through other files, and a claim spelled there would
/// rewrite a user's hand-edited profiles at start-up.
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
        // One per door: the save tail, the load, the pick.
        #expect(counts == [claimDoors: 3], Comment(rawValue: stray))
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
