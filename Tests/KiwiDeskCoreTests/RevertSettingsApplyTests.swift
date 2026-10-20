import Foundation
import Testing

@testable import KiwiDeskCore

/// `revert_settings`' apply (#2411): a reverted leaf is applied the
/// way its setter applies it — an explicit retile, and the session
/// shadow of a sizing leaf dropped so the stored value draws.
@Suite("Revert settings apply", .serialized)
@MainActor
struct RevertSettingsApplyTests {
    /// A core whose live profile keeps its own look.
    private func ownLookCore() throws -> KiwiCore {
        let core = try KeepFixture.core()
        try core.profiles.save(KeepFixture.profile("Odd"))
        KeepFixture.load("Odd", core)
        return core
    }

    @Test("a reverted leaf runs a retile")
    func revertRetiles() throws {
        let core = try ownLookCore()
        _ = core.execute("border.set_width", args: [.number(9)])
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        core.revertUnsavedLive(["/settings/border/width"])
        let counts = meter.snapshot(reset: false).counts
        #expect(counts.retiles + counts.passesHeld >= 1)
    }

    /// A drag's session ratio outranks the stored one, so a revert
    /// that left it would draw nothing; the Space's own drag on an
    /// untouched axis stays.
    @Test("a reverted sizing leaf drops its session shadow")
    func sizingShadowDrops() throws {
        let core = try ownLookCore()
        let space = SpaceID("1")
        _ = core.execute("bsp.set_ratio_h", args: [.number(0.7)])
        core.state.workspaces.withSpace(space) {
            $0.sessionRatios.splitRatioH = 0.3
            $0.sessionRatios.splitRatioV = 0.4
        }
        let outcome = core.revertUnsavedLive(["/settings/bsp/ratio_h"])
        #expect(outcome.refused.isEmpty)
        let ratios = try #require(core.state.workspaces[space])
            .sessionRatios
        #expect(ratios.splitRatioH == nil)
        #expect(ratios.splitRatioV == 0.4)
    }

    /// The shadow table mirrors `SessionRatios`: a field added there
    /// with no entry here would leave its drag over every revert.
    @Test("every session field has a shadow entry")
    func everyFieldHasAnEntry() {
        let fields = Mirror(reflecting: SessionRatios()).children.count
        #expect(KiwiCore.sizingShadows.count == fields)
        var cleared = 0
        for shadow in KiwiCore.sizingShadows {
            var ratios = SessionRatios()
            ratios.splitRatioH = 0.1
            ratios.splitRatioV = 0.1
            ratios.masterRatio = 0.1
            ratios.slotSize = .auto
            ratios.gridColumnWeights = [1]
            ratios.gridRowWeights = [1]
            let before = Mirror(reflecting: ratios).children
                .filter { "\($0.value)" != "nil" }.count
            shadow.clear(&ratios)
            let after = Mirror(reflecting: ratios).children
                .filter { "\($0.value)" != "nil" }.count
            if before - after == 1 { cleared += 1 }
        }
        #expect(cleared == fields)
    }
}
