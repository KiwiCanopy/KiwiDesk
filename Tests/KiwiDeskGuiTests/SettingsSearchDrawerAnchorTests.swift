import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Where a census hit behind a disclosure LANDS (#277, #1250):
/// on a catalog child its drawer expands for, never on the
/// destination root with the drawer shut. Split from
/// `SettingsSearchAnchorTests`, which owns the surface and
/// breadcrumb rules for the rest of the index. English pinned
/// per body (#90).
@Suite("Settings search drawer anchors", .serialized)
@MainActor
struct SettingsSearchDrawerAnchorTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    /// The census containers whose `.showMore` rows a drawer
    /// hides, each with its destination — a container name
    /// recurs across areas (`.appBar` holds Bars' Style rows AND
    /// Advanced Colours') — its English title, and the drawers
    /// that draw it: two where a container is split across
    /// disclosures (`.gaps`). The membership of each container
    /// is the census's, read live, so a new row landing in one
    /// of them anchor-less reds here without a count. A drawer
    /// declared with children joins this register, one declared
    /// childless joins `SettingsCatalogDrawerTests`', and
    /// `filledRegisterIsComplete` refuses a third state.
    private var filledDrawers:
        [(
            SettingsDestination, String, SettingsContainer,
            [any AnySettingsDrawer]
        )]
    {
        [
            (
                .general, "General", .advanced,
                [SettingsCatalog.general.generalAdvanced]
            ),
            (
                .gapsAndBorders, "Gaps & Borders", .gaps,
                [
                    SettingsCatalog.gapsAndBorders.gapsPerEdge,
                    SettingsCatalog.gapsAndBorders.gapsPerAxis,
                ]
            ),
            (
                .bars, "Bars", .spaceBar,
                [SettingsCatalog.bars.spaceBarStyle]
            ),
            (
                .bars, "Bars", .appBar,
                [SettingsCatalog.bars.appBarStyle]
            ),
            (
                .colors, "Colors & Animations", .motion,
                [SettingsCatalog.colors.motionMore]
            ),
            (
                .shortcuts, "Shortcuts", .generalKeys,
                [SettingsCatalog.shortcuts.generalKeys]
            ),
        ]
    }

    /// The indexed census rows placed in `container` — by
    /// container alone, never by tier: a row's tier is what the
    /// census SAYS about its rendering, and a guard keyed on it
    /// reds when the census is corrected rather than when the
    /// join breaks.
    private func indexedRows(
        in destination: SettingsDestination,
        _ container: SettingsContainer
    ) -> [SettingKey] {
        SettingKey.allCases.filter {
            $0.placement.area == destination.area
                && $0.placement.container == container
                && SettingsSearchIndex.indexes($0)
        }
    }

    /// Every drawer the catalog declares with children, by id —
    /// reflection over each destination container, the way the
    /// childless register derives its set.
    private var declaredFilledDrawers: Set<String> {
        var found: Set<String> = []
        for destination in SettingsDestination.allCases {
            let container = SettingsCatalog.container(
                of: destination
            )
            for child in Mirror(reflecting: container).children {
                guard let drawer = child.value as? AnySettingsDrawer,
                    !(drawer.childContainer is SettingsNoChildren)
                else { continue }
                found.insert(drawer.control.id)
            }
        }
        return found
    }

    /// The register above names every drawer declared with
    /// children and no other — so a drawer filled without
    /// joining it, or a stale entry, reds here rather than
    /// leaving its container's join unheld.
    @Test("the filled-drawer register is complete")
    func filledRegisterIsComplete() {
        let registered = Set(
            filledDrawers.flatMap { $0.3 }.map(\.control.id)
        )
        let declared = declaredFilledDrawers
        #expect(!declared.isEmpty)
        #expect(
            registered == declared,
            Comment(
                rawValue:
                    "unregistered: "
                    + declared.subtracting(registered).sorted()
                    .joined(separator: ", ")
                    + " | stale: "
                    + registered.subtracting(declared).sorted()
                    .joined(separator: ", ")
            )
        )
    }

    /// The #1250 defect, held for every filled drawer: a
    /// disclosure is collapsed by default, and a census hit
    /// inside it used to land on the destination root, drawer
    /// shut, row unrendered. Over every indexed row of a
    /// registered container, the anchor follows the census
    /// tier: a `.showMore` row carries one that EXACTLY ONE of
    /// the container's drawers expands for, its breadcrumb
    /// naming that drawer, and an `.atRest` row (the gap
    /// masters, a bar's edge, the Show-it-in toggles that
    /// self-anchor at rest) is inside NO drawer, so its
    /// breadcrumb is the destination alone.
    @Test("a hit inside a filled drawer opens it")
    func drawerHitsOpenTheirDrawer() {
        pinEnglish()
        defer { reset() }
        let rows = SettingsSearchIndex.rows()
        for (destination, title, container, drawers)
            in filledDrawers
        {
            let held = indexedRows(in: destination, container)
            let hidden = held.filter {
                $0.placement.tier == .showMore
            }
            // Non-vacuity only — each membership is its own
            // census-render suite's, never a count pinned here.
            #expect(!hidden.isEmpty, Comment(rawValue: "\(container)"))
            for key in held {
                let row = rows.first { $0.key == key }
                let anchor = row?.anchor.anchor
                let opening = drawers.filter {
                    $0.shouldExpand(revealing: anchor)
                }
                if key.placement.tier == .showMore {
                    #expect(anchor != nil, Comment(rawValue: key.id))
                    #expect(
                        opening.count == 1,
                        Comment(rawValue: key.id)
                    )
                } else {
                    #expect(
                        opening.isEmpty,
                        Comment(rawValue: key.id)
                    )
                }
                #expect(
                    row?.path == [title] + opening.map(\.control.text),
                    Comment(rawValue: key.id)
                )
            }
        }
    }

    /// The Focus border and Sticky rows: an anchor follows the
    /// census TIER, both ways (`docs/design-decisions.md` ▸ a
    /// search hit lands on the control only where the section
    /// hides it) — a `.showMore` row lands on its own control,
    /// breadcrumb the destination alone, and an `.atRest` row
    /// carries none; since #1473 every row of both cards is at
    /// rest, so the clause holds the second arm alone until a
    /// disclosure returns. Read with the bridge present so the
    /// sticky reach row is indexed. The drag ghost / drop zone `Border`
    /// and `Fill` rows are the stated residue: two census rows
    /// share one label key per column, and the label-key join
    /// reads no instance, so they stay anchor-less until the
    /// census row carries one — never resolved onto the first
    /// column declared. The premise is asserted rather than the
    /// count: every anchor-less drag row shares its label key.
    @Test("a Gaps & Borders row lands on its own control")
    func gapsAndBordersRowsCarryAnchors() {
        pinEnglish()
        defer { reset() }
        let before = SettingsSearchIndex.canDriveDesktops
        defer { SettingsSearchIndex.canDriveDesktops = before }
        SettingsSearchIndex.canDriveDesktops = true
        let rows = SettingsSearchIndex.rows()
        for container in [
            SettingsContainer.focusBorder, .stickyWindows,
        ] {
            let held = indexedRows(in: .gapsAndBorders, container)
            #expect(!held.isEmpty, Comment(rawValue: "\(container)"))
            for key in held {
                let row = rows.first { $0.key == key }
                let hidden = key.placement.tier == .showMore
                #expect(
                    (row?.anchor.anchor != nil) == hidden,
                    Comment(rawValue: key.id)
                )
                #expect(
                    row?.path == ["Gaps & Borders"],
                    Comment(rawValue: key.id)
                )
            }
        }
        let drag = indexedRows(in: .gapsAndBorders, .dragAndDrop)
            .filter { key in
                let row = rows.first { $0.key == key }
                return row?.anchor.anchor == nil
            }
        #expect(!drag.isEmpty)
        let byLabel = Dictionary(grouping: drag) { key -> String in
            guard case .key(let k) = key.text.label else { return "" }
            return k
        }
        for (label, keys) in byLabel {
            #expect(keys.count > 1, Comment(rawValue: label))
        }
    }

    /// A control a census row names is refused WITH that row:
    /// `SettingsSearchIndex.build` claims it off every labelled
    /// census row of the area, indexed or not, so a row `indexes`
    /// refuses on this machine — the glass card below macOS 26
    /// — never resurfaces its control as a catalog-only row for
    /// something nothing draws. Held generally: no catalog-only
    /// row's control carries a label key any census row of its
    /// area does. Stated residue: on a host where nothing is
    /// refused (macOS 26+, the bridge present) every such
    /// control is claimed by its indexed row and the clause
    /// cannot see the construction it names; only a pre-26
    /// runner exercises it.
    @Test("a refused census row takes its control with it")
    func refusedRowsKeepTheirControls() {
        pinEnglish()
        defer { reset() }
        let before = SettingsSearchIndex.canDriveDesktops
        defer { SettingsSearchIndex.canDriveDesktops = before }
        for bridge in [false, true] {
            SettingsSearchIndex.canDriveDesktops = bridge
            let rows = SettingsSearchIndex.rows()
            let extras = rows.filter { $0.key == nil }
            #expect(!extras.isEmpty)
            for extra in extras {
                let labelled = Set(
                    SettingKey.allCases
                        .filter {
                            $0.placement.area
                                == extra.destination.area
                        }
                        .compactMap { key -> String? in
                            guard case .key(let k) = key.text.label
                            else { return nil }
                            return k
                        }
                )
                let entry = SettingsCatalog.entries(
                    of: extra.destination
                )
                .first { $0.control.id == extra.anchor.anchor }
                #expect(
                    entry?.control.key.map(labelled.contains)
                        != true,
                    Comment(rawValue: extra.id)
                )
            }
        }
        let glass = SettingsCatalog.colors.glassCard.id
        let glassRow = SettingsSearchIndex.rows().first {
            $0.anchor.anchor == glass
        }
        #expect((glassRow != nil) == AppBarStyle.glassAvailable)
    }

    /// The two bars' Style drawers share one label key and are
    /// told apart by instance; their rows carry the bar's OWN
    /// keys, so the join lands each census row on its own bar's
    /// child rather than the first drawer declared. Pinned on
    /// the one row both bars have under the same English.
    @Test("a bar's row lands on its own bar's drawer")
    func barRowsLandOnTheirOwnBar() {
        pinEnglish()
        defer { reset() }
        let rows = SettingsSearchIndex.rows()
        let space = rows.first {
            $0.key == .spaceBar(.spaceBarFontSize)
        }
        let app = rows.first { $0.key == .appBar(.appBarFontSize) }
        #expect(space?.anchor.anchor == "space_bar.font_size")
        #expect(app?.anchor.anchor == "app_bar.font_size")
        #expect(
            SettingsCatalog.bars.spaceBarStyle.shouldExpand(
                revealing: space?.anchor.anchor
            )
        )
        #expect(
            !SettingsCatalog.bars.appBarStyle.shouldExpand(
                revealing: space?.anchor.anchor
            )
        )
    }
}
