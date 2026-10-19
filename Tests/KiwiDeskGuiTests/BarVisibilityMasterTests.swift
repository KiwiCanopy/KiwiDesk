import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// KiwiShelf's Show master (#761): every bar's own visibility from
/// one row, with no segment selected and a `?` while they differ,
/// and the followers behind it read off Core's hosting set.
@MainActor
@Suite("Bar visibility master (#761)")
struct BarVisibilityMasterTests {
    private func split() -> SettingsModel {
        let model = makeTestModel()
        model.config.settings.setEveryBarVisibility(.always)
        model.config.settings.scrolling.appBar.visibility = .hidden
        return model
    }

    @Test("an agreed value selects its segment; a split selects none")
    func masterShowsTheSharedValue() {
        let model = split()
        #expect(model.barVisibilityMaster.wrappedValue == nil)
        #expect(
            GapsBordersGates(settings: model.config.settings)
                .followersDiffer(for: .kiwishelf(.visibility))
        )
        model.config.settings.scrolling.appBar.visibility = .always
        #expect(model.barVisibilityMaster.wrappedValue == .always)
        #expect(
            !GapsBordersGates(settings: model.config.settings)
                .followersDiffer(for: .kiwishelf(.visibility))
        )
    }

    @Test("a pick sets every bar, and a re-pick writes nothing")
    func pickSetsEveryBar() {
        let model = split()
        model.barVisibilityMaster.wrappedValue = .auto
        let settings = model.config.settings
        #expect(settings.spaceBarStyle.visibility == .auto)
        #expect(settings.appBarHosts.allSatisfy { $0.visibility == .auto })
        let before = model.config
        model.barVisibilityMaster.wrappedValue = .auto
        model.barVisibilityMaster.wrappedValue = nil
        #expect(model.config == before)
    }

    /// The master's leaves are each hosting layout's, read off the
    /// same `appBarHost` the reservation asks, so a third hosting
    /// layout joins the master without an edit here.
    @Test("the master's leaves book as one change, the hosting set")
    func masterOwnsEveryLeaf() {
        let hosts = LayoutMode.allCases
            .filter { TilingSettings().appBarHost(for: $0) != nil }
            .map { "settings.\($0.rawValue).appBar.visibility" }
        #expect(
            Set(SettingKey.masterWrites[.kiwishelf(.visibility)] ?? [])
                == Set(["settings.spaceBarStyle.visibility"] + hosts)
        )
    }

    @Test("the followers sit behind Each bar, the master at rest")
    func followersBehindTheDrawer() {
        #expect(BarsRowOrder.kiwishelfShow.first == .kiwishelf(.visibility))
        for key in BarsRowOrder.kiwishelfShowEach {
            #expect(key.placement.tier == .showMore, "\(key.id)")
        }
    }
}
