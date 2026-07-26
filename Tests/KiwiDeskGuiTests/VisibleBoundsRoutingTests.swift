import Foundation
import Testing

/// Layout, capacity and resize spans must resolve their display
/// bounds through `TilingEngine.visibleBounds`, never by calling
/// `GeometryUtils.axVisibleFrame` directly (#531): a direct call
/// re-imports the host's real screen, and a fixture that pins
/// the hook then silently stops pinning that path.
///
/// The routed call sites each have a behavioural test today, so
/// this guard is not what covers them — it is what covers the
/// *next* one, which arrives before its test does. Two of the
/// four went in routed but uncovered, and reverting either left
/// all 1979 tests green; that is the gap this closes on arrival
/// rather than in review.
///
/// **The lens, not the list.** The scan discovers *every*
/// occurrence under the three governed directories and pins a
/// per-file count, so a new direct call in an unlisted file
/// fails on arrival, and a removed one in a listed file fails
/// too (a count that can only ever be met by the status quo is
/// the shape of a guard that has quietly stopped guarding).
///
/// It lives in the GUI test target purely because `SourceScan`
/// does: copying the enumerator into `KiwiDeskCoreTests` is the
/// exact drift `.claude/rules/tests.md` ratified that helper to
/// avoid. It scans `Sources/KiwiDeskCore`, not the GUI tree.
///
/// The needle is the **bare** `axVisibleFrame`, not the
/// qualified call. Matching `GeometryUtils.axVisibleFrame` failed
/// OPEN — a §2.2 hard wrap between the type and the member hid a
/// call in an unlisted file, and `swift format` keeps that wrap,
/// so the violation would have been formatter-blessed and
/// permanently invisible (found in review). The bare name is
/// declared in exactly one place, whose own declaration is
/// allowlisted below.
///
/// Remaining limit, which fails **shut**: a call reached through
/// a new helper that itself calls the direct API from an
/// allowlisted file is invisible.
@Suite("Visible-bounds routing")
struct VisibleBoundsRoutingTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// The directories where a direct call would re-import the
    /// host screen: `Tiling` and `Layouts` own the layout path,
    /// `Commands` owns the resize spans (and is covered by no
    /// `.claude/rules/*` file, so this guard is the only reminder
    /// an agent editing it gets), and `App` is where every live
    /// exception actually lives — scanning only the first three
    /// would have watched the files that are already correct and
    /// missed the ones deliberately outside the hook (review).
    private let governed = [
        "Tiling", "Layouts", "Commands", "App",
    ]

    /// Every file allowed to name `axVisibleFrame` directly, with
    /// today's exact count and the reason it is outside the hook.
    /// Anything absent from this map must be at zero.
    ///
    /// **This map is the exemption list.** AGENTS.md §5 and the
    /// `visibleBounds` doc comment carry the principle and point
    /// here for the files, rather than restating them — three
    /// prose copies drifted apart on their first outing (review).
    private let allowed: [String: Int] = [
        // The declaration itself.
        "GeometryUtils.swift": 1,
        // The hook's own default.
        "TilingEngine.swift": 1,
        // `screen(containing:)` is static — no instance in hand.
        "TilingEngine+Layout.swift": 1,
        // Parking *enumerates* `NSScreen.screens` to pick a
        // corner; a one-rect hook would collapse every display
        // onto the same bounds.
        "TilingEngine+Stash.swift": 3,
        "TilingEngine+StashRestore.swift": 2,
        // The bar strips are drawn ON a screen; a fabricated rect
        // would place real chrome nowhere.
        "KiwiCore+AppBar.swift": 2,
        "KiwiCore+SpaceBar.swift": 1,
        // DO NOT ROUTE. Re-anchor resolves the source AND the
        // destination screen and early-returns when they are
        // equal — under a one-rect hook they always are, so
        // routing it would silently disable a default-ON feature
        // (#502) in every pinned fixture while staying green.
        "KiwiCore+FloatReanchor.swift": 2,
    ]

    @Test("Only the allowlisted files resolve bounds directly")
    func directCallsStayInsideTheAllowlist() throws {
        var counts: [String: Int] = [:]
        for directory in governed {
            let root =
                coreRoot
                .appendingPathComponent(directory)
            for file in try SourceScan.swiftSources(under: root) {
                let source = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                let hits = source.occurrences(
                    of: "axVisibleFrame"
                )
                guard hits > 0 else { continue }
                counts[file.lastPathComponent, default: 0] += hits
            }
        }
        for (file, count) in counts.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) names axVisibleFrame \(count) time(s); "
                + "route those bounds through tiler.visibleBounds, "
                + "or justify and re-pin the count here"
            #expect(
                allowed[file] == count,
                Comment(rawValue: unlisted)
            )
        }
        // The inverse: an allowlisted call that vanished means
        // the entry is now unfalsifiable and should be dropped.
        for (file, expected) in allowed {
            let vanished =
                "\(file) no longer names axVisibleFrame "
                + "\(expected) time(s) — drop or re-pin its "
                + "allowlist entry"
            #expect(
                counts[file] == expected,
                Comment(rawValue: vanished)
            )
        }
    }
}
