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
            BarsRowOrder.kiwishelfStyle
            + BarsRowOrder.kiwishelfMargins
        #expect(Set(rendered) == censusRows(.kiwishelf, .showMore))
        #expect(rendered.count == Set(rendered).count)
    }

    @Test("Space Bar at-rest rows are the census's")
    func spaceBarAtRest() {
        #expect(
            Set(BarsRowOrder.spaceBarAtRest)
                == censusRows(.spaceBar, .atRest)
        )
        #expect(
            BarsRowOrder.spaceBarAtRest.count
                == Set(BarsRowOrder.spaceBarAtRest).count
        )
    }

    @Test("Space Bar Style rows are the census's show-more set")
    func spaceBarStyle() {
        #expect(
            Set(BarsRowOrder.spaceBarStyle)
                == censusRows(.spaceBar, .showMore)
        )
        #expect(
            BarsRowOrder.spaceBarStyle.count
                == Set(BarsRowOrder.spaceBarStyle).count
        )
    }

    @Test("App Bar at-rest rows are the census's")
    func appBarAtRest() {
        #expect(
            Set(BarsRowOrder.appBarAtRest)
                == censusRows(.appBar, .atRest)
        )
        #expect(
            BarsRowOrder.appBarAtRest.count
                == Set(BarsRowOrder.appBarAtRest).count
        )
    }

    @Test("App Bar Style rows are the census's show-more set")
    func appBarStyle() {
        #expect(
            Set(BarsRowOrder.appBarStyle)
                == censusRows(.appBar, .showMore)
        )
        #expect(
            BarsRowOrder.appBarStyle.count
                == Set(BarsRowOrder.appBarStyle).count
        )
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

    /// Each bar container's block gate resolves to a reason
    /// against the live draft — the wholesale grey each editor
    /// had, now returned as a `BarsGates.InertReason` rather than
    /// a Bool. `onlyTwoContainers` pins WHICH containers gate;
    /// this pins that the resolver answers each correctly.
    @Test("container gates resolve against the draft")
    func containerGatesResolve() {
        var settings = TilingSettings()
        settings.spaceBarStyle.enabled = false
        settings.monocle.appBar.enabled = false
        settings.scrolling.appBar.enabled = false
        var gates = BarsGates(settings: settings)
        #expect(gates.containerReason(for: .spaceBar) == .spaceBarOff)
        #expect(gates.containerReason(for: .appBar) == .noBarShown)

        settings.spaceBarStyle.enabled = true
        settings.scrolling.appBar.enabled = true
        gates = BarsGates(settings: settings)
        #expect(gates.containerReason(for: .spaceBar) == nil)
        #expect(gates.containerReason(for: .appBar) == nil)

        settings.scrolling.appBar.enabled = false
        settings.monocle.appBar.enabled = true
        gates = BarsGates(settings: settings)
        #expect(gates.containerReason(for: .appBar) == nil)
    }

    /// The bar cards' gate owners — the Show rows — live on the
    /// KiwiShelf card, which has no gate, so none of them needs
    /// an exemption to stay live (#1517); the one rider is the
    /// symbol-style picker the ⌃⌥K panel reads. A red here asks
    /// the real question: is this new exemption a rider with an
    /// argument?
    @Test("gate owners sit on the ungated shelf; one rider")
    func exemptSet() {
        let owners = [SettingsContainer.spaceBar, .appBar]
            .flatMap { $0.gate?.settings ?? [] }
        #expect(!owners.isEmpty)
        for owner in owners {
            #expect(owner.placement.container == .kiwishelf)
        }
        #expect(SettingsContainer.kiwishelf.gate == nil)
        let exempt = Set(
            SettingKey.allCases.filter {
                $0.placement.area == .bars
                    && $0.placement.exemptFromContainerGate
            }
        )
        #expect(exempt == [.appBar(.appBarIconSource)])
    }

    /// Core's `appBarHost(for:)` is "the one place that decides
    /// which layouts host an App Bar"; the census's `.appBar`
    /// container gate re-lists that set as its `anyOf` owners.
    /// Pin the two together, derived from Core: a third hosting
    /// layout added in Core must red here until the census
    /// `.appBar` gate's owners learn it — otherwise that layout's
    /// own Show toggle is missing from the KiwiShelf card and no
    /// row can switch that layout's bar on (#527's failure).
    @Test("the App Bar gate's owners are Core's hosting set")
    func appBarGateOwnersMatchCoreHosting() {
        let owners = Set(
            (SettingsContainer.appBar.gate?.settings ?? [])
                .map(\.id)
        )
        let hosts = Set(
            LayoutMode.allCases
                .filter {
                    TilingSettings().appBarHost(for: $0) != nil
                }
                .map { "settings.\($0.rawValue).appBar.enabled" }
        )
        #expect(owners == hosts)
    }
}
