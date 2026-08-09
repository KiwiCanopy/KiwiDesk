import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the shared card's two masters WRITE (#754). Nothing
/// else can see it: the census records two rows, the gate suite
/// records no gate on them, and a master that moves one stroke
/// and leaves the other two ships a card whose whole claim —
/// one width and one corner for every border — is false at the
/// pixel. What each master SHOWS, and what happens when the
/// strokes disagree, is `BorderMastersDivergenceTests`.
@MainActor
@Suite("Border masters fan-out")
struct BorderMastersFanOutTests {
    private func model() -> SettingsModel {
        makeTestModel()
    }

    /// Pin the defaults this suite reasons from: all three
    /// strokes ship the SAME width, the drag pair's radius
    /// ships at the very constant Rounded writes, and the ring
    /// ships the corner STYLE that radius stands for — so an
    /// untouched config already agrees with what the two rows
    /// show and neither master has to write to make it true
    /// (tests.md — a fixture pins any default it reasons from).
    /// The ring's style is the half the picker cannot infer
    /// from the radius, so flipping it alone would otherwise
    /// ship a card showing Rounded over a square ring.
    @Test("the shipped strokes already agree")
    func shippedStrokesAgree() {
        let settings = TilingSettings()
        #expect(
            settings.borderStyle.width
                == settings.dragGhost.borderWidth
        )
        #expect(
            settings.borderStyle.width
                == settings.dragDropZone.borderWidth
        )
        #expect(settings.borderStyle.cornerStyle == .rounded)
        #expect(
            settings.dragCornerRadius
                == GeometryUtils.systemWindowCornerRadius
        )
    }

    @Test("the width master writes all three strokes")
    func widthFansOut() {
        let model = model()
        model.borderWidthMaster.wrappedValue = 11
        let settings = model.config.settings
        #expect(settings.borderStyle.width == 11)
        #expect(settings.dragGhost.borderWidth == 11)
        #expect(settings.dragDropZone.borderWidth == 11)
    }

    /// Square is the ring's square style AND a zero radius;
    /// Rounded is the ring's rounded style AND, where there is
    /// no rounding to keep, the system window radius. Two
    /// stored shapes, one decision.
    @Test("the corner master writes all three strokes")
    func cornersFanOut() {
        let model = model()
        model.borderCornersMaster.wrappedValue = .square
        #expect(
            model.config.settings.borderStyle.cornerStyle
                == .square
        )
        #expect(model.config.settings.dragCornerRadius == 0)
        model.borderCornersMaster.wrappedValue = .rounded
        #expect(
            model.config.settings.borderStyle.cornerStyle
                == .rounded
        )
        #expect(
            model.config.settings.dragCornerRadius
                == GeometryUtils.systemWindowCornerRadius
        )
    }

    /// The census's `masterWrites` is a second copy of what the
    /// bindings above write, kept because the unsaved-changes
    /// count cannot reach a `Binding`. This is what stops the
    /// two drifting: write each master, walk the config, and
    /// require the leaves that MOVED to be exactly the declared
    /// list. A master growing a fourth stroke reds here.
    @Test("the declared fan-out is what a master writes")
    func declarationMatchesTheWrite() {
        expectWrites(
            .borders(.borderWidthMaster),
            by: { $0.borderWidthMaster.wrappedValue = 11 }
        )
        expectWrites(
            .borders(.borderCornerMaster),
            by: { $0.borderCornersMaster.wrappedValue = .square }
        )
    }

    /// No two masters may claim one leaf: `censusBases()`
    /// registers them by override, so an overlap would make the
    /// count depend on dictionary iteration order.
    @Test("no leaf is claimed by two masters")
    func fanOutListsAreDisjoint() {
        let all = SettingKey.masterWrites.values.flatMap { $0 }
        #expect(!all.isEmpty)
        #expect(Set(all).count == all.count)
    }

    /// The header's "N unsaved changes". One nudge of a master
    /// is one change the user made, whatever it took to store
    /// it — the count read 3 for a Width nudge and 2 for a
    /// Corners tap until the fan-out was declared.
    @Test("one master edit counts as one unsaved change")
    func oneEditCountsOnce() {
        expectOneChange(
            .borders(.borderWidthMaster),
            by: { $0.borderWidthMaster.wrappedValue = 11 }
        )
        expectOneChange(
            .borders(.borderCornerMaster),
            by: { $0.borderCornersMaster.wrappedValue = .square }
        )
    }

    // MARK: - Helpers

    private func expectWrites(
        _ key: SettingKey,
        by edit: (SettingsModel) -> Void
    ) {
        let model = model()
        let before = SettingsDraftDiff.leaves(of: model.config)
        edit(model)
        let after = SettingsDraftDiff.leaves(of: model.config)
        let moved = Set(before.keys).union(after.keys)
            .filter { before[$0] != after[$0] }
        #expect(
            moved == Set(SettingKey.masterWrites[key] ?? []),
            Comment(
                rawValue:
                    "\(key.id) writes \(moved.sorted()) — "
                    + "SettingKey.masterWrites disagrees"
            )
        )
    }

    private func expectOneChange(
        _ key: SettingKey,
        by edit: (SettingsModel) -> Void
    ) {
        let model = model()
        let clean = model.config
        edit(model)
        let diff = SettingsDraftDiff.between(
            config: model.config,
            cleanConfig: clean
        )
        #expect(diff.unattributed.isEmpty)
        #expect(
            diff.changedSettings == [key],
            Comment(
                rawValue:
                    "one edit of \(key.id) counted as "
                    + "\(diff.changedSettings.map(\.id))"
            )
        )
    }
}
