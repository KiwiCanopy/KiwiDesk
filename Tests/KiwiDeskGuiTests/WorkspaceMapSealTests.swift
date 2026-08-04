import Foundation
import Testing

/// `WorkspaceManager`'s backing maps went `private` → internal
/// so the `+Displays` split (§2.1 file ceiling) could read them
/// cross-file — which also lets any `KiwiDeskCore` file compile
/// a direct write. The write invariants live in the methods, not
/// the maps: every `spaceDisplay` write must run `ensureSpace`
/// plus the stale-`secondaryShown` filter (`assign(_:to:)`), and
/// a stray `secondaryShown` write strands exactly the entries
/// that filter exists to drop. This pins the maps' names to the
/// two `WorkspaceManager*` files, so a third toucher must add
/// itself here and say why.
///
/// **This map is the exemption list** — the property comments in
/// `WorkspaceManager` point here rather than restating it.
///
/// Limits, stated so the next author knows where the net ends:
/// the other two widened stores, `order` and `displays`, are
/// UNGUARDED by this scan — both names collide across the module
/// (z-order, `KiwiCore.displays`, locals), so a name scan would
/// either drown in exemptions or need needles this repo's
/// formatter can wrap apart (the `VisibleBoundsRoutingTests`
/// fail-open lesson). Their write risk is also lower: their
/// writers are single-statement upserts with no paired-step
/// invariant. A future seam that gives them one owes this suite
/// a needle or the maps a re-privatization.
@Suite("Workspace map seal")
struct WorkspaceMapSealTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// Per needle: every file allowed to name it, by path under
    /// `Sources/KiwiDeskCore`, with today's exact count (comments
    /// stripped). Keyed by path so same-named files never pool.
    private let allowed: [String: [String: Int]] = [
        "spaceDisplay": [
            "State/WorkspaceManager.swift": 6,
            "State/WorkspaceManager+Displays.swift": 6,
        ],
        "secondaryShown": [
            "State/WorkspaceManager.swift": 6,
            "State/WorkspaceManager+Displays.swift": 3,
        ],
    ]

    @Test("The display maps are named only where declared")
    func mapNamesStayInsideTheAllowlist() throws {
        let root = coreRoot
        let prefix = root.path + "/"
        var counts: [String: [String: Int]] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            for needle in allowed.keys {
                let hits = source.occurrences(of: needle)
                guard hits > 0 else { continue }
                counts[needle, default: [:]][key] = hits
            }
        }
        for (needle, files) in counts {
            for (file, count) in files.sorted(
                by: { $0.key < $1.key }
            ) {
                let stray =
                    "\(file) names \(needle) \(count) time(s); "
                    + "route through the WorkspaceManager API "
                    + "(assign/removeDisplay), or justify and "
                    + "pin the count here"
                #expect(
                    allowed[needle]?[file] == count,
                    Comment(rawValue: stray)
                )
            }
        }
        // The inverse: a pinned count that vanished means the
        // entry is unfalsifiable — and a mistyped root reds here
        // instead of passing vacuously.
        for (needle, files) in allowed {
            for (file, expected) in files {
                let vanished =
                    "\(file) no longer names \(needle) "
                    + "\(expected) time(s) — drop or re-pin "
                    + "its entry"
                #expect(
                    counts[needle]?[file] == expected,
                    Comment(rawValue: vanished)
                )
            }
        }
    }
}
