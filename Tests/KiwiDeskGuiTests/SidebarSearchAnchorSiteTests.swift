import Foundation
import Testing

/// One anchor key, one mounted view — the guard that keeps
/// text-as-identity honest until the per-control descriptor lands
/// (#277).
///
/// `SidebarSearchAnchorTests` pins that no two index *entries*
/// share a label. That is index-shaped, and the hazard is
/// tree-shaped: a single key rendered at several sites that are on
/// screen *together* is one index entry, one text — and three
/// `.id("Fill")`s in one `ScrollView`, where `scrollTo` is
/// undefined and every matching view washes at once. The index
/// guard cannot see it, which is why this one counts **sites**.
///
/// It has teeth immediately: the App Bar surface renders each of
/// its eight colour rows and ~12 style rows three times over
/// (global plus the Monocle and Scrolling override drawers) once
/// those drawers are open. None of that is anchored yet — the
/// catalog will anchor it — and this fails the moment it is,
/// rather than shipping a plural flash.
@Suite("Sidebar search anchor sites")
struct SidebarSearchAnchorSiteTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// Keys deliberately anchored at more than one site, with the
    /// count and the reason that makes it safe. **Mutual exclusion
    /// is the only admissible reason**: the two sites must never be
    /// mounted together, so the shared id is never ambiguous.
    ///
    /// Fail-shut in both directions — an unlisted duplicate fails,
    /// and a listed key whose count no longer matches fails too.
    /// That second half is the point: both `bars.advanced_colors`
    /// anchors are load-bearing (the index carries that label
    /// surface-free so a reveal lands on whichever bar editor is
    /// open), and before this guard, deleting either one left every
    /// test green while silently restoring the scroll-to-nothing
    /// bug for that side.
    private let alternatelyMounted: [String: Int] = [
        // The App Bar and Space Bar colour drawers. `BarsSection`
        // renders exactly one editor per `switch model.barEditor`.
        "bars.advanced_colors": 2,
        // `MonitorsSection`'s cards section and its
        // "not connected" read-only twin are if/else branches.
        "monitors.space_placement": 2,
    ]

    @Test("no anchor key is claimed by two co-mounted views")
    func anchorKeysAreClaimedOnce() throws {
        var sites: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: settingsDir) {
            let source = try String(
                contentsOf: file,
                encoding: .utf8
            )
            // Counted per file *and* summed across files: the
            // duplicate can be two call sites in one view or the
            // same label in two views of one destination.
            for key in try SourceScan.anchorSiteKeys(in: source) {
                sites[key, default: 0] += 1
            }
        }
        // A zero would make every check below vacuous.
        #expect(sites.count >= 30)

        for (key, count) in sites.sorted(by: { $0.key < $1.key }) {
            guard let allowed = alternatelyMounted[key] else {
                #expect(
                    count == 1,
                    Comment(
                        rawValue:
                            "\(key) is anchored at \(count) sites."
                            + " Anchor identity is the label text,"
                            + " so co-mounted twins make scrollTo"
                            + " undefined and flash both. Either"
                            + " give them distinct labels, or add"
                            + " the key to alternatelyMounted with"
                            + " the reason they cannot co-render."
                    )
                )
                continue
            }
            #expect(
                count == allowed,
                Comment(
                    rawValue:
                        "\(key) is anchored at \(count) sites, "
                        + "not the \(allowed) alternatelyMounted "
                        + "records. Both sides are load-bearing; "
                        + "a dropped one reveals nothing on that "
                        + "surface."
                )
            )
        }

        // And the allow-list itself must stay real.
        for key in alternatelyMounted.keys {
            #expect(
                sites[key] != nil,
                Comment(
                    rawValue:
                        "stale alternatelyMounted entry: \(key) "
                        + "is no longer anchored anywhere"
                )
            )
        }
    }
}
