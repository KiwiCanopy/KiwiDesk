import Foundation
import Testing

/// Layout, capacity and resize spans must resolve their display
/// bounds through `TilingEngine.visibleBounds`, never by calling
/// `GeometryUtils.axVisibleFrame` directly (#531): a direct call
/// re-imports the host's real screen, and a fixture that pins
/// the hook then silently stops pinning that path.
///
/// Some routed sites carry a behavioural test of their own; the
/// float nudge carries only this guard. Either way its job is
/// the *next* call site, which arrives before its test does —
/// two went in routed but uncovered, and reverting either left
/// the whole behavioural suite green.
///
/// This guards the layer *below* `LayoutBoundsRoutingTests`
/// (#537): here, nobody bypasses the hook; there, nobody
/// consumes it raw where the layout *region* is meant. Both are
/// needed — routing through this hook and then dividing by the
/// whole display passes this suite and is still the bug. The two
/// do **not** compose over each other's allowlists: a file
/// exempted here names `visibleBounds` zero times, so a span
/// measured inside one is invisible to both.
///
/// **The lens, not the list.** The scan discovers *every*
/// occurrence under `Sources/KiwiDeskCore` and pins a per-file
/// count, so a new direct call in an unlisted file fails on
/// arrival, and a removed one in a listed file fails too (a
/// count that can only ever be met by the status quo is the
/// shape of a guard that has quietly stopped guarding). It scans
/// the whole target rather than the layout directories because
/// a directory filter is a second, unwritten exemption axis: a
/// new file one directory over would need no entry and record no
/// reason (review). Zero occurrences live outside the listed
/// files today, so the wider net costs nothing.
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
/// Two limits remain, and both fail **OPEN** — an unseen call is
/// a silent pass, so neither is benign: a call reached through a
/// new helper that itself calls the direct API from an
/// allowlisted file is invisible, and `SourceScan.stripComments`
/// cuts each line at its first `//`, so a URL in a string
/// literal preceding a call on the same line would erase it.
///
/// It lives in the GUI test target purely because `SourceScan`
/// does: copying the enumerator into `KiwiDeskCoreTests` is the
/// exact drift `.claude/rules/tests.md` ratified that helper to
/// avoid. It scans `Sources/KiwiDeskCore`, not the GUI tree.
@Suite("Visible-bounds routing")
struct VisibleBoundsRoutingTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// Every file allowed to name `axVisibleFrame` directly, by
    /// path under `Sources/KiwiDeskCore`, with today's exact
    /// count and the reason it is outside the hook. Anything
    /// absent from this map must be at zero. Keyed by path, not
    /// basename, so two same-named files can never pool counts
    /// and mask each other.
    ///
    /// **This map is the exemption list.** The state-and-layout
    /// rule and the `visibleBounds` doc comment carry the
    /// principle and point
    /// here for the files, rather than restating them — three
    /// prose copies drifted apart on their first outing (review).
    private let allowed: [String: Int] = [
        // The declaration itself.
        "Tiling/GeometryUtils.swift": 1,
        // The hook's own default, and the `allScreenBounds`
        // topology hook's default (#878) — that one enumerates
        // `NSScreen.screens` for the neighbor scan, the same
        // several-screens shape as parking below, and is itself
        // an injectable seam the test factories pin.
        "Tiling/TilingEngine.swift": 2,
        // `screen(containing:)` is static — no instance in hand.
        "Tiling/TilingEngine+Layout.swift": 1,
        // Parking *enumerates* `NSScreen.screens` to pick a
        // corner; a one-rect hook would collapse every display
        // onto the same bounds.
        "Tiling/TilingEngine+Stash.swift": 3,
        "Tiling/TilingEngine+StashRestore.swift": 2,
        // The bar strips are drawn ON a screen; a fabricated rect
        // would place real chrome nowhere.
        "App/KiwiCore+AppBar.swift": 2,
        "App/KiwiCore+SpaceBar.swift": 1,
        // DO NOT ROUTE. Re-anchor resolves the source AND the
        // destination screen and early-returns when they are
        // equal — under a one-rect hook they always are, so
        // routing it would silently disable a default-ON feature
        // (#502) in every pinned fixture while staying green.
        "App/KiwiCore+FloatReanchor.swift": 2,
    ]

    @Test("Only the allowlisted files resolve bounds directly")
    func directCallsStayInsideTheAllowlist() throws {
        var counts: [String: Int] = [:]
        let root = coreRoot
        let prefix = root.path + "/"
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hits = source.occurrences(of: "axVisibleFrame")
            guard hits > 0 else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            counts[key, default: 0] += hits
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
        // It is also what proves the scanner reached real files —
        // a mistyped root yields zero hits everywhere and reds
        // here rather than passing vacuously.
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
