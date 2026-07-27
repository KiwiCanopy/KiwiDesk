import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The catalog's structural invariants (#277 part 2): ids are
/// unique, surfaces fit their destinations, and the drawer
/// containment that drives auto-expand is real. Pure data tests
/// over `SettingsCatalog.entries(of:)` — the source-scanning
/// guards live in `SettingsCatalogSiteTests`.
@Suite("Settings catalog")
struct SettingsCatalogTests {
    private var allEntries: [(SettingsDestination, SettingsIndexEntry)] {
        SettingsDestination.allCases.flatMap { destination in
            SettingsCatalog.entries(of: destination).map {
                (destination, $0)
            }
        }
    }

    /// Ids are the anchor identity, so a duplicate inside one
    /// destination is `scrollTo`-undefined the moment both
    /// mounts render. The one legitimate shared id —
    /// `bars.advanced_colors` on the two mutually-exclusive bar
    /// editors — is a single declaration, so it enumerates once
    /// and passes trivially; a second *declaration* reusing an
    /// id fails here.
    @Test("anchor ids are unique per destination")
    func idsAreUniquePerDestination() {
        for destination in SettingsDestination.allCases {
            let ids = SettingsCatalog.entries(of: destination)
                .map(\.control.id)
            #expect(!ids.isEmpty)
            #expect(
                ids.count == Set(ids).count,
                Comment(
                    rawValue:
                        "\(destination) declares a duplicate "
                        + "anchor id: "
                        + ids.sorted().joined(separator: ", ")
                )
            )
        }
    }

    /// Pinned totals, so a shrunken enumeration cannot make the
    /// sweeps above vacuous while still passing. 48 declared
    /// tuples (incl. the two bar-switch entries) + 6 computed mode
    /// tabs. Update deliberately as the catalog fills.
    @Test("the enumeration count is pinned")
    func entryCountIsPinned() {
        #expect(allEntries.count == 54)
        // And the two-ground split behind that number.
        let modeTabs = allEntries.filter {
            $0.1.control.key == nil
        }
        #expect(modeTabs.count == 6)
    }

    /// Catalog property names are the tokens
    /// `SettingsCatalogSiteTests` greps render sites for, so a
    /// duplicate name would make its reference check count two
    /// declarations as one. Mode tabs have no property (empty
    /// path) and are checked by their factory instead.
    @Test("catalog property names are unique catalog-wide")
    func propertyNamesAreUnique() {
        let names =
            allEntries
            .compactMap { $0.1.propertyPath.last }
        #expect(!names.isEmpty)
        #expect(
            names.count == Set(names).count,
            Comment(
                rawValue:
                    "duplicate catalog property name(s): "
                    + names.sorted().joined(separator: ", ")
            )
        )
    }

    /// Every stored member of every catalog container must be a
    /// `SettingsControl` or a `SettingsDrawer` — otherwise the
    /// reflection enumerator drops it silently and it ships
    /// rendered-but-unsearchable, the exact hole the one-list
    /// design closes. Both reviewers flagged this as the net's one
    /// gap before the ~250-control fill (a `[SettingsControl]`
    /// collection is the realistic first offender). Fails loudly
    /// the moment such a member appears, naming its path.
    @Test("no catalog member escapes the enumerator")
    func everyStoredMemberIsEnumerated() {
        for destination in SettingsDestination.allCases {
            let dropped = SettingsControlIndex.unenumerated(
                in: SettingsCatalog.container(of: destination)
            )
            #expect(
                dropped.isEmpty,
                Comment(
                    rawValue:
                        "\(destination) has catalog member(s) the "
                        + "enumerator drops (not a SettingsControl "
                        + "/ SettingsDrawer): "
                        + dropped.joined(separator: ", ")
                        + " — a search hit on them reveals nothing"
                )
            )
        }
    }

    /// A catalog property name doubles as the token
    /// `catalogDeclarationsAreReferenced` greps render sites for
    /// (`.\(name)`), and that check is a *substring* match with no
    /// count backstop for leaf controls. A name equal to a common
    /// identifier (`.title`, `.name`) would match unrelated tokens
    /// tree-wide, so a genuinely-dead declaration would false-pass
    /// — reintroducing the part-1 dead-entry bug for the one class
    /// (drawer children) the exact-total guards do not cover.
    /// `propertyNamesAreUnique` pins uniqueness; this pins
    /// distinctiveness.
    @Test("catalog property names are distinctive")
    func propertyNamesAreDistinctive() {
        let generic: Set<String> = [
            "title", "name", "label", "text", "id", "caption",
            "card", "header", "control", "value", "body",
            "content", "key", "row", "item",
        ]
        let names =
            allEntries
            .compactMap { $0.1.propertyPath.last }
        for name in names {
            #expect(
                !generic.contains(name),
                Comment(
                    rawValue:
                        "catalog property '\(name)' collides with "
                        + "a common identifier — its dotted "
                        + "reference check would match unrelated "
                        + "tokens; rename it distinctively"
                )
            )
        }
    }

    /// The surface of every entry must be one this destination
    /// can actually show — a `.layoutMode` on Bars would select
    /// nothing and the reveal would scroll to a view that is not
    /// there.
    @Test("entry surfaces belong to their destination")
    func surfacesMatchDestination() {
        for (destination, entry) in allEntries {
            switch entry.control.surface {
            case .main:
                continue
            case .layoutMode(let mode):
                #expect(destination == .layoutDefaults)
                // Floating has no tab (it renders `EmptyView`),
                // so selecting it would reveal nothing — the
                // case alone is not enough.
                #expect(
                    LayoutMode.placementTabs.contains(mode)
                )
            case .bar:
                #expect(destination == .bars)
            }
        }
    }

    /// The auto-expand decision `SettingsDisclosure` consumes
    /// (#277 part 2): a reveal on an interior child must open
    /// its parent drawer; a direct hit on the drawer's own
    /// label must NOT (the header is visible and highlighted —
    /// opening it is one honest click, part-1 design call).
    @Test("a drawer expands for its children and nothing else")
    func drawerExpansionDecision() {
        let perEdge = SettingsCatalog.appearance.gapsPerEdge
        let edges = perEdge.children
        for child in [
            edges.edgeTop, edges.edgeBottom,
            edges.edgeLeft, edges.edgeRight,
        ] {
            #expect(
                perEdge.shouldExpand(revealing: child.id),
                Comment(rawValue: child.id)
            )
        }
        let perAxis = SettingsCatalog.appearance.gapsPerAxis
        let axes = perAxis.children
        #expect(
            perAxis.shouldExpand(
                revealing: axes.axisHorizontal.id
            )
        )
        #expect(
            perAxis.shouldExpand(revealing: axes.axisVertical.id)
        )
        // Own label: one honest click, never auto-expand.
        #expect(
            !perEdge.shouldExpand(
                revealing: perEdge.control.id
            )
        )
        // Not mine / nobody's.
        #expect(!perEdge.shouldExpand(revealing: "gaps.title"))
        #expect(!perEdge.shouldExpand(revealing: nil))
        // A leaf drawer never expands for anything.
        #expect(
            !SettingsCatalog.bars.advancedColors.shouldExpand(
                revealing: "gaps.top"
            )
        )
    }

    /// The enumeration must link a drawer's children to their
    /// drawer — the breadcrumb and the reveal both lean on it.
    @Test("drawer children carry their parent")
    func drawerChildrenCarryParent() {
        let appearance = SettingsCatalog.entries(of: .appearance)
        let top = appearance.first {
            $0.control.id == "gaps.top"
        }
        #expect(top?.parent?.id == "gaps.per_edge")
        #expect(
            top?.propertyPath == ["gapsPerEdge", "edgeTop"]
        )
        // Top-level entries carry none.
        let gaps = appearance.first {
            $0.control.id == "gaps.title"
        }
        #expect(gaps != nil)
        #expect(gaps?.parent == nil)
    }

    /// The two co-mounted `LayoutAppBarGroup` declarations must
    /// stay distinct — collapsing them back to one shared id is
    /// exactly the `scrollTo`-undefined shape the instance tag
    /// exists to prevent.
    @Test("co-mounted drawer instances have distinct ids")
    func instanceIdsAreDistinct() {
        let monocle = SettingsCatalog.bars.monocleBarOverrides
        let scrolling =
            SettingsCatalog.bars.scrollingBarOverrides
        #expect(
            monocle.control.id
                == "monocle/app_bar.layout.overrides"
        )
        #expect(
            scrolling.control.id
                == "scrolling/app_bar.layout.overrides"
        )
        #expect(monocle.control.key == scrolling.control.key)
    }
}
