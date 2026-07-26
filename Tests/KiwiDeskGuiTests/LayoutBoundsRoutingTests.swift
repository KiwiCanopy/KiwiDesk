import Foundation
import Testing

/// The second altitude of the bounds seam (#537). `visibleBounds`
/// (#531) answers *how big is the display*;
/// `TilingEngine.layoutBounds(on:)` answers *how big is the region
/// the layouts divide* — the display minus the Space Bar's strip
/// (#293). Anything that measures a layout span must read the
/// second, and four resize paths read the first raw: a delta over
/// a strip-inflated span understated every ratio nudge, and the
/// scrolling slot stored its points against the wrong length.
///
/// The sibling `VisibleBoundsRoutingTests` guards the layer below
/// (nobody bypasses the hook); this one guards nobody *consuming*
/// the hook where the region is meant. Both are needed: routing
/// through `visibleBounds` and then dividing by the whole display
/// satisfies that guard and is still the bug.
///
/// **The lens, not the list** — same shape as its sibling, for the
/// same reasons. The scan discovers every occurrence under
/// `Sources/KiwiDeskCore` and pins a per-file count, so a new raw
/// consumer in an unlisted file fails on arrival *and* a vanished
/// one in a listed file fails too (a count only the status quo can
/// meet is a guard that has stopped guarding). Whole target, not a
/// directory list: a directory filter is a second, unwritten
/// exemption axis.
///
/// The needle is the **bare** `visibleBounds`, never
/// `tiler.visibleBounds` — a §2.2 hard wrap between the receiver
/// and the member is `swift format`-blessed, so a qualified needle
/// would fail OPEN and stay invisible (the #531 review found
/// exactly that wrap hiding a call). Its two non-call sites, the
/// declaration and the seam, are allowlisted below.
///
/// Same two open failure modes as the sibling, and neither is
/// benign: a call reached through a new helper inside an
/// allowlisted file is invisible, and `SourceScan.stripComments`
/// cuts at the first `//`, so a `//` inside a string literal
/// preceding a call on that line would erase it.
@Suite("Layout-bounds routing")
struct LayoutBoundsRoutingTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// Every file allowed to name `visibleBounds` — the raw
    /// display size — with today's exact count and the reason it
    /// is not reading the layout region. Keyed by path, so two
    /// same-named files cannot pool counts.
    ///
    /// **This map is the exemption list**; the prose in
    /// `SpaceBarGeometry` and AGENTS.md §5 points here instead of
    /// keeping a copy, because three prose copies of the sibling's
    /// list drifted apart on their first outing.
    private let allowed: [String: Int] = [
        // The hook's own declaration.
        "Tiling/TilingEngine.swift": 1,
        // The `layoutBounds(on:)` seam — the one legitimate
        // consumer, and what every span reads through.
        "Tiling/TilingEngine+Layout.swift": 1,
        // A float nudge moves a window that does NOT participate
        // in the layout, so it may cross the strip: its bound is
        // the display, and reserving the region would trap floats
        // out of it.
        "App/KiwiCore+FloatNudge.swift": 1,
    ]

    @Test("Only the allowlisted files read raw display bounds")
    func rawConsumersStayInsideTheAllowlist() throws {
        var counts: [String: Int] = [:]
        let root = coreRoot
        let prefix = root.path + "/"
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hits = source.occurrences(of: "visibleBounds")
            guard hits > 0 else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            counts[key, default: 0] += hits
        }
        for (file, count) in counts.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) names visibleBounds \(count) time(s); a "
                + "layout span reads tiler.layoutBounds(on:) so "
                + "the Space Bar's strip is reserved, or justify "
                + "and re-pin the count here"
            #expect(
                allowed[file] == count,
                Comment(rawValue: unlisted)
            )
        }
        // The inverse: a vanished call makes its entry
        // unfalsifiable. It is also what proves the scanner
        // reached real files — a mistyped root reds here instead
        // of passing vacuously.
        for (file, expected) in allowed {
            let vanished =
                "\(file) no longer names visibleBounds "
                + "\(expected) time(s) — drop or re-pin its "
                + "allowlist entry"
            #expect(
                counts[file] == expected,
                Comment(rawValue: vanished)
            )
        }
    }
}
