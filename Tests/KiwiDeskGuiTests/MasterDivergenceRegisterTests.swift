import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Who answers a master's `?` while its followers disagree
/// (#1383): `GapsBordersGates.acknowledged` is the one register,
/// and no other census key may answer.
@MainActor
@Suite("Master divergence register")
struct MasterDivergenceRegisterTests {
    /// Every registered master's followers disagreeing at once.
    private func allDiverging() -> GapsBordersGates {
        var settings = TilingSettings()
        settings.gapsGlobal.outer.bottom += 3
        settings.gapsGlobal.inner.vertical += 3
        settings.appBarStyle.edge = .bottom
        return GapsBordersGates(settings: settings)
    }

    /// Read both ways on that fixture: each member answers, and
    /// the default arm stays silent for every other key rather
    /// than answering for the census.
    @Test("the acknowledged register is exactly who answers the ?")
    func acknowledgedRegisterIsExact() {
        let gates = allDiverging()
        #expect(!GapsBordersGates.acknowledged.isEmpty)
        for key in GapsBordersGates.acknowledged {
            #expect(
                gates.followersDiffer(for: key),
                Comment(rawValue: "\(key.id) is registered but silent")
            )
            #expect(key.placement.gate == nil)
        }
        for key in SettingKey.allCases
        where !GapsBordersGates.acknowledged.contains(key) {
            #expect(
                !gates.followersDiffer(for: key),
                Comment(rawValue: "\(key.id) answers unregistered")
            )
        }
    }

    /// `censusBases()` registers each master's writes by
    /// override, so an overlap would make the unsaved-change
    /// count depend on dictionary iteration order.
    @Test("no leaf is claimed by two masters")
    func fanOutListsAreDisjoint() {
        let all = SettingKey.masterWrites.values.flatMap { $0 }
        #expect(!all.isEmpty)
        #expect(Set(all).count == all.count)
    }
}
