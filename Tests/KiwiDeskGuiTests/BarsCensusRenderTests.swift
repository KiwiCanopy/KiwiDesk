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
        let rendered =
            BarsRowOrder.appBarAtRest + BarsRowOrder.appBarShowIn
        #expect(Set(rendered) == censusRows(.appBar, .atRest))
        #expect(rendered.count == Set(rendered).count)
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

    /// The area's render knows exactly two containers; a third
    /// would mount nowhere, so it must fail loud here rather
    /// than ship an unreachable row.
    @Test("the Bars area holds only the two bar containers")
    func onlyTwoContainers() {
        let containers = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .bars }
                .compactMap { $0.placement.container }
        )
        #expect(containers == [.spaceBar, .appBar])
    }

    /// The card gates resolve the census containers' own gates
    /// (`SettingsContainer.gate`) against the live draft — the
    /// wholesale grey each editor had, now census-driven.
    @Test("container gates resolve against the draft")
    func containerGatesResolve() {
        var settings = TilingSettings()
        settings.spaceBarStyle.enabled = false
        settings.monocle.appBar.enabled = false
        settings.scrolling.appBar.enabled = false
        var gates = BarsGateContext(settings: settings)
        #expect(!gates.allowsEditing(.spaceBar))
        #expect(!gates.allowsEditing(.appBar))

        settings.spaceBarStyle.enabled = true
        settings.scrolling.appBar.enabled = true
        gates = BarsGateContext(settings: settings)
        #expect(gates.allowsEditing(.spaceBar))
        #expect(gates.allowsEditing(.appBar))

        settings.scrolling.appBar.enabled = false
        settings.monocle.appBar.enabled = true
        gates = BarsGateContext(settings: settings)
        #expect(gates.allowsEditing(.appBar))
    }

    /// The rows the census exempts from their container's gate
    /// are exactly the ones that must stay live: the gate's own
    /// owners (or the lockout is permanent), the symbol-style
    /// picker the ⌃⌥K panel reads, and the copy action gated on
    /// the *other* bar. A renderer honors this as data, so the
    /// set itself is what must not drift.
    @Test("the exempt set is the gate owners plus the two riders")
    func exemptSet() {
        let exempt = Set(
            SettingKey.allCases.filter {
                $0.placement.area == .bars
                    && $0.placement.exemptFromContainerGate
            }
        )
        #expect(
            exempt == [
                .spaceBar(.spaceBarEnabled),
                .layoutAppBar(.monocleAppBarEnabled),
                .layoutAppBar(.scrollingAppBarEnabled),
                .appBar(.appBarIconSource),
                .spaceBar(.copyAppearance),
            ]
        )
    }
}
