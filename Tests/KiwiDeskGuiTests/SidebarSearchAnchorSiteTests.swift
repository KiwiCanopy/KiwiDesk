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
/// It has teeth on the shape that matters most: the App Bar's
/// eight colour rows live at two source sites
/// (`AppBarGroups+Colors` and `LayoutAppBarColorOverrides`), so
/// anchoring them counts 2 and trips.
///
/// KNOWN LIMIT, because it counts **source sites** and therefore
/// assumes one mount per site. `BarsSection` instantiates
/// `LayoutAppBarGroup` **twice, co-mounted** (Monocle and
/// Scrolling), so anything anchored inside it is one source site
/// and two mounted views with identical text — invisible here.
/// Its drawer label `app_bar.layout.overrides` is the live example
/// and sits in `SidebarSearchParityTests.unindexed`, i.e. next in
/// line for the catalog. Note the arithmetic that follows: those
/// eight colour keys are 2 source sites but **3** co-mounted
/// views, so `alternatelyMounted`'s value is a source-site count
/// and NOT a mount count — do not record one for the other.
///
/// The durable answer is the one `app_bar.layout.title` already
/// uses: a per-instance label built with `%1$@`, so each mount
/// carries its own text and the ambiguity cannot arise.
@Suite("Sidebar search anchor sites")
struct SidebarSearchAnchorSiteTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// Keys deliberately anchored at more than one **source
    /// site**, with that site count and the reason it is safe.
    /// **Mutual exclusion is the only admissible reason**: the
    /// sites must never be mounted together, so the shared id is
    /// never ambiguous. See the suite docstring on why a site
    /// count is not a mount count.
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
        // renders one editor per `switch model.nav.barEditor`.
        "bars.advanced_colors": 2,
        // `MonitorsSection`'s cards section and its
        // "not connected" read-only twin are if/else branches.
        "monitors.space_placement": 2,
    ]

    @Test("no anchor key is claimed by two co-mounted views")
    func anchorKeysAreClaimedOnce() throws {
        var sites: [String: Int] = [:]
        var sections = 0
        var explicit = 0
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
            sections +=
                try SourceScan
                .sectionHeaderKeys(in: source).count
            explicit +=
                try SourceScan
                .searchAnchorKeys(in: source).count
        }
        // Exact, not a floor. A floor of 30 against 43 real keys
        // would still pass if the `.searchAnchor` half of
        // `anchorSiteKeys` stopped matching — which is precisely
        // what a modifier rename did between rounds — leaving six
        // anchor sites unexamined while every survivor read 1.
        #expect(sites.count == 43)
        // And each pattern must contribute, so neither half can go
        // quiet while the total is made up by the other. These two
        // count DISTINCT keys per file, so a key anchored twice in
        // one file lands once here while `sites` records both —
        // which is why the three numbers do not sum naively.
        #expect(sections == 37)
        #expect(explicit == 7)

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
