import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// KiwiShelf's Position master (#1731): both bars' edges from one
/// row, with no segment selected and a `?` while they sit apart,
/// and the rows that only mean something on a shared edge greyed.
@MainActor
@Suite("Bar edge master (#1731)")
struct BarEdgeMasterTests {
    private func split() -> SettingsModel {
        let model = makeTestModel()
        model.config.settings.spaceBarStyle.enabled = true
        model.config.settings.monocle.appBar.enabled = true
        model.config.settings.spaceBarStyle.edge = .top
        model.config.settings.appBarStyle.edge = .bottom
        return model
    }

    @Test("a shared edge selects its segment; a split selects none")
    func masterShowsTheSharedEdge() {
        let model = split()
        #expect(model.barEdgeMaster.wrappedValue == nil)
        #expect(
            GapsBordersGates(settings: model.config.settings)
                .followersDiffer(for: .kiwishelf(.edge))
        )
        model.config.settings.appBarStyle.edge = .top
        #expect(model.barEdgeMaster.wrappedValue == .top)
        #expect(
            !GapsBordersGates(settings: model.config.settings)
                .followersDiffer(for: .kiwishelf(.edge))
        )
    }

    @Test("a pick puts both bars on it, and a re-pick writes nothing")
    func pickRefuses() {
        let model = split()
        model.barEdgeMaster.wrappedValue = .left
        #expect(model.config.settings.spaceBarStyle.edge == .left)
        #expect(model.config.settings.appBarStyle.edge == .left)
        let before = model.config
        model.barEdgeMaster.wrappedValue = .left
        model.barEdgeMaster.wrappedValue = nil
        #expect(model.config == before)
    }

    @Test("order and minimum grey while the bars are split")
    func sharedEdgeRowsGrey() {
        let model = split()
        let gates = BarsGates(settings: model.config.settings)
        #expect(gates.bothBarsReason == .barsSplit)
        model.config.settings.appBarStyle.edge = .bottom
        model.config.settings.spaceBarStyle.edge = .bottom
        #expect(
            BarsGates(settings: model.config.settings).bothBarsReason == nil
        )
    }

    @Test("the master's leaves book as one change")
    func masterOwnsBothLeaves() {
        #expect(
            Set(SettingKey.masterWrites[.kiwishelf(.edge)] ?? [])
                == [
                    "settings.spaceBarStyle.edge", "settings.appBarStyle.edge",
                ]
        )
    }
}
