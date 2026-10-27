import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let ids = (1...6).map { WindowID(UInt32($0)) }
private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

/// A corroborated learned floor of `span` (two refused asks).
private func floor(_ span: CGFloat) -> [EffectiveSizeBound.Axis] {
    [
        .init(asked: 250, answered: span),
        .init(asked: 200, answered: span),
    ]
}

/// Usable 1900 × 1060 at gap 10, min 300: a fixed 3 × 2 grid fits.
private func context(autoSize: Bool = false) -> LayoutContext {
    var context = LayoutContext(bounds: screen, gaps: .uniform(10))
    context.grid.type = .rigid
    context.grid.columns = 3
    context.grid.rows = 2
    context.grid.autoSize = autoSize
    return context
}

/// The grid heals from its largest window's floor (#2687): the
/// ceiling fits the widest and tallest minimum among the Space's
/// windows, fixed or auto-sized, and grows back once it leaves.
@Suite("Grid heals from the largest floor")
struct GridHealTests {
    @Test("a wide window takes a column away from a fixed grid")
    func fixedGridLosesAColumn() throws {
        var ctx = context()
        let before = try #require(GridLayout.shape(for: ids, in: ctx))
        #expect(before.columns == 3)
        ctx.sizeBounds[ids[4]] = EffectiveSizeBound(width: floor(900))
        let healed = try #require(GridLayout.shape(for: ids, in: ctx))
        #expect(healed.columns == 2)
        #expect(healed.rows == 2)
        #expect(healed.scrolls)
    }

    @Test("a tall window takes a row away from an auto-sized grid")
    func autoGridLosesARow() throws {
        var ctx = context(autoSize: true)
        let before = try #require(GridLayout.shape(for: ids, in: ctx))
        ctx.sizeBounds[ids[0]] = EffectiveSizeBound(height: floor(600))
        let healed = try #require(GridLayout.shape(for: ids, in: ctx))
        #expect(healed.rows < before.rows)
        #expect(healed.rows == 1)
    }

    @Test("the grid grows back once the wide window leaves")
    func growsBack() throws {
        var ctx = context()
        ctx.sizeBounds[ids[4]] = EffectiveSizeBound(width: floor(900))
        let shape = try #require(GridLayout.shape(for: ids, in: ctx))
        #expect(shape.columns == 2)
        let rest = ids.filter { $0 != ids[4] }
        let back = try #require(GridLayout.shape(for: rest, in: ctx))
        #expect(back.columns == 3)
    }

    @Test("the overflow run scrolls what the healed cells drop")
    func runFollows() throws {
        var ctx = context()
        #expect(GridLayout.zones(for: ids, in: ctx) == [])
        ctx.sizeBounds[ids[4]] = EffectiveSizeBound(width: floor(900))
        let zones = try #require(GridLayout.zones(for: ids, in: ctx))
        #expect(zones.count == 1)
    }

    @Test("a forced pass probes past the floor at the full grid")
    func forcedPassIgnoresTheFloor() throws {
        var ctx = context()
        ctx.sizeBounds[ids[4]] = EffectiveSizeBound(width: floor(900))
        ctx.sizeBounds[ids[0]] = EffectiveSizeBound(height: floor(600))
        ctx.probesBeyondBounds = true
        let shape = try #require(GridLayout.shape(for: ids, in: ctx))
        #expect(shape.columns == 3)
        #expect(shape.rows == 2)
    }

    @Test("the drawn cells follow the healed shape")
    func geometryFollows() throws {
        var ctx = context()
        ctx.sizeBounds[ids[4]] = EffectiveSizeBound(width: floor(900))
        let frames = GridLayout().calculateGeometry(for: ids, in: ctx)
        let first = try #require(frames[ids[0]])
        #expect(first.width >= 900)
    }
}
