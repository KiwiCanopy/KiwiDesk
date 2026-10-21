import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Bars area renders FROM the census (#678 Phase 2): the
/// census owns placement, `BarsRowOrder` owns display order.
/// These pin the two together — every `.bars`-area census key
/// appears in exactly the order list its placement names, so a
/// census row added, retiered or moved without a renderer
/// update is a red test, not a silently missing control.
@Suite("Bars render ↔ census parity")
struct BarsCensusRenderTests {
    private func censusRows(
        _ container: SettingsContainer,
        _ tier: SettingTier
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .bars
                    && $0.placement.container == container
                    && $0.placement.tier == tier
            }
        )
    }

    @Test("KiwiShelf at-rest rows are the census's")
    func kiwishelfAtRest() {
        let rendered =
            BarsRowOrder.kiwishelfShow + BarsRowOrder.kiwishelfAtRest
        #expect(Set(rendered) == censusRows(.kiwishelf, .atRest))
        #expect(rendered.count == Set(rendered).count)
    }

    @Test("KiwiShelf drawer rows are the census's show-more set")
    func kiwishelfDrawers() {
        let rendered =
            BarsRowOrder.kiwishelfShowEach
            + BarsRowOrder.kiwishelfDurations
            + BarsRowOrder.kiwishelfEdges
            + BarsRowOrder.kiwishelfStyle
            + BarsRowOrder.kiwishelfMargins
        #expect(Set(rendered) == censusRows(.kiwishelf, .showMore))
        #expect(rendered.count == Set(rendered).count)
    }

    /// The bar cards have no drawer (#1517): every row is at
    /// rest, and the card draws exactly the census's set.
    @Test(
        "A bar card draws every census row at rest",
        arguments: [
            (SettingsContainer.spaceBar, BarsRowOrder.spaceBar),
            (.appBar, BarsRowOrder.appBar),
        ]
    )
    func barCardRows(container: SettingsContainer, rows: [SettingKey]) {
        #expect(Set(rows) == censusRows(container, .atRest))
        #expect(censusRows(container, .showMore).isEmpty)
        #expect(rows.count == Set(rows).count)
    }

    /// The area's render knows exactly three containers; a
    /// fourth would mount nowhere, so it must fail loud here
    /// rather than ship an unreachable row.
    @Test("the Bars area holds the shelf and the two bar cards")
    func onlyThreeContainers() {
        let containers = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .bars }
                .compactMap { $0.placement.container }
        )
        #expect(containers == [.kiwishelf, .spaceBar, .appBar])
    }

    /// A hidden bar's shortcut still shows it, so no bar
    /// container greys for a bar's value (#761): every container's
    /// gate is gone, and the resolver answers nil for each even
    /// with every bar hidden.
    @Test("no bar container greys for a bar's value")
    func noContainerGreys() {
        var settings = TilingSettings()
        settings.spaceBarStyle.visibility = .hidden
        settings.monocle.appBar.visibility = .hidden
        settings.scrolling.appBar.visibility = .hidden
        for container in [SettingsContainer.kiwishelf, .spaceBar, .appBar] {
            #expect(container.gate == nil)
        }
        let exempt = Set(
            SettingKey.allCases.filter {
                $0.placement.area == .bars
                    && $0.placement.exemptFromContainerGate
            }
        )
        #expect(exempt.isEmpty)
    }

    /// Core's `appBarHost(for:)` is "the one place that decides
    /// which layouts host an App Bar"; the Show group draws one
    /// visibility row per such layout. Pin the two together,
    /// derived from Core: a third hosting layout added in Core reds
    /// here until the Show group learns it — otherwise no row could
    /// set that layout's App Bar (#527's failure).
    @Test("the Show group's App Bar rows are Core's hosting set")
    func appBarRowsMatchCoreHosting() {
        let rows = Set(
            BarsRowOrder.kiwishelfShowEach
                .filter {
                    if case .layoutAppBar = $0 { return true }
                    return false
                }
                .map(\.id)
        )
        let hosts = Set(
            LayoutMode.allCases
                .filter {
                    TilingSettings().appBarHost(for: $0) != nil
                }
                .map { "settings.\($0.rawValue).appBar.visibility" }
        )
        #expect(rows == hosts)
    }
}
