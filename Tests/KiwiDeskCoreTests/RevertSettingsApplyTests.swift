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
        core.withSessionRatios(of: space) {
            $0.splitRatioH = 0.3
            $0.splitRatioV = 0.4
        }
        let ids = try #require(core.unsavedLiveSettings()).leaves.keys
        #expect(ids.count == 1)
        #expect(ids.first?.hasSuffix("/ratio_h") == true)
        let outcome = core.revertUnsavedLive(Array(ids))
        #expect(outcome.refused.isEmpty)
        #expect(outcome.reverted.count == 1)
        let ratios = core.sessionRatios(of: space)
        #expect(ratios.splitRatioH == nil)
        #expect(ratios.splitRatioV == 0.4)
    }

    /// Every field, set, for a clear to find.
    private func fullRatios() -> SessionRatios {
        var ratios = SessionRatios()
        ratios.splitRatioH = 0.1
        ratios.splitRatioV = 0.1
        ratios.masterRatio = 0.1
        ratios.slotSize = .auto
        ratios.gridColumnWeights = [1]
        ratios.gridRowWeights = [1]
        var splits = BspSplitRatios()
        splits.set(0.1, of: WindowID(1), sideBySide: true)
        splits.set(0.1, of: WindowID(1), sideBySide: false)
        ratios.bspSplits = splits
        return ratios
    }

    /// The labels of `ratios`' fields that hold a value, the BSP
    /// splits one per axis (#3672).
    private func setLabels(_ ratios: SessionRatios) -> Set<String> {
        var labels = Set(
            Mirror(reflecting: ratios).children.compactMap { child in
                "\(child.value)" == "nil" ? nil : child.label
            }
        )
        labels.remove("bspSplits")
        if ratios.bspSplits?.horizontal.isEmpty == false {
            labels.insert("bspSplits.h")
        }
        if ratios.bspSplits?.vertical.isEmpty == false {
            labels.insert("bspSplits.v")
        }
        return labels
    }

    /// The splits an axis's shared ratio clears with it (#3672).
    private let axisSplits = [
        "splitRatioH": "bspSplits.h",
        "splitRatioV": "bspSplits.v",
    ]

    /// The shadow table mirrors `SessionRatios`: each entry clears
    /// one field, no two the same, and together every field — a
    /// field added there with no entry leaves its drag over every
    /// revert.
    @Test("every session field has a shadow entry")
    func everyFieldHasAnEntry() {
        let all = setLabels(fullRatios())
        let fields = Mirror(reflecting: SessionRatios()).children.count
        #expect(all.count == fields + 1)
        var cleared: [String] = []
        for shadow in KiwiCore.sizingShadows {
            var ratios = fullRatios()
            shadow.clear(&ratios)
            let gone = all.subtracting(setLabels(ratios))
            let shared = gone.subtracting(axisSplits.values)
            #expect(shared.count == 1)
            #expect(
                gone == shared.union(shared.compactMap { axisSplits[$0] })
            )
            cleared += gone
        }
        #expect(cleared.count == Set(cleared).count)
        #expect(Set(cleared) == all)
    }

    /// Each entry reads the leaf its field shadows: a global write
    /// of that leaf moves exactly the entry that clears the field.
    @Test("each entry reads the leaf it clears")
    func entriesReadTheirLeaf() {
        let writes: [String: (inout TilingSettings) -> Void] = [
            "splitRatioH": { $0.bsp.splitRatioH = 0.9 },
            "splitRatioV": { $0.bsp.splitRatioV = 0.9 },
            "masterRatio": { $0.stack.masterRatio = 0.9 },
            "slotSize": { $0.scrolling.slotSize = .points(321) },
            "gridColumnWeights": { $0.grid.columnWeights = [2, 1] },
            "gridRowWeights": { $0.grid.rowWeights = [2, 1] },
        ]
        let all = setLabels(fullRatios())
        #expect(Set(writes.keys) == all.subtracting(axisSplits.values))
        let old = TilingSettings()
        for (label, write) in writes {
            var new = old
            write(&new)
            let moved = KiwiCore.sizingShadows.filter {
                $0.movedGlobally(old, new)
            }
            #expect(moved.count == 1, "\(label)")
            guard let shadow = moved.first else { continue }
            var ratios = fullRatios()
            shadow.clear(&ratios)
            #expect(
                all.subtracting(setLabels(ratios))
                    == Set([label] + [axisSplits[label]].compactMap { $0 })
            )
        }
    }
}
