import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A run weight step that flips the render between the whole split
/// and floor-and-share (#2967), on zones the seeded property suite
/// reaches only by luck: where the weight nearest the length asked
/// moves the window the other way, and where no weight moves it the
/// way asked; and a step a hiding run clamps at the weight's limit
/// (#3634). Pure.
@Suite("Run zone weight step across the whole split (#2967)")
struct RunZoneCrossingTests {
    /// A horizontal zone `span` wide, one window per floor, with
    /// the given weights; nil leaves a window's weight unset.
    private func zone(
        span: CGFloat,
        floors: [CGFloat],
        weights: [Double?]
    ) -> (RunZone, LayoutContext) {
        let ids = floors.indices.map { WindowID(UInt32($0 + 1)) }
        let zone = RunZone(
            members: ids,
            region: CGRect(x: 0, y: 0, width: span, height: 600),
            vertical: false
        )
        var context = LayoutContext(
            bounds: zone.region,
            focused: ids[0],
            minWindowSize: 200
        )
        for (id, floor) in zip(ids, floors) {
            context.sizeBounds[id] = EffectiveSizeBound(width: [
                .init(asked: 50, answered: floor)
            ])
        }
        for (id, weight) in zip(ids, weights) {
            context.stackWeights[id] = weight
        }
        return (zone, context)
    }

    /// `press` stored as the writers store it.
    private func applying(
        _ press: RunZone.Press,
        of id: WindowID,
        to zone: RunZone,
        in context: LayoutContext
    ) -> LayoutContext {
        var after = context
        if let weight = press.weight { after.stackWeights[id] = weight }
        for (member, share) in press.sizes {
            after.runSizes[member] = share.map {
                RunSize(share: $0, zone: zone.ordinal)
            }
        }
        if let visible = press.visible {
            (after.runHeads, after.runTails) = zone.ends(
                showing: visible,
                heads: after.runHeads,
                tails: after.runTails
            )
        }
        return after
    }

    private func width(
        _ id: WindowID,
        _ zone: RunZone,
        _ context: LayoutContext
    ) -> CGFloat {
        zone.frames(in: context)[id]?.width ?? 0
    }

    @Test("A shrink takes the weight that shrinks, not the nearest one")
    func shrinkSkipsTheNearestWrongWay() throws {
        // The step lands in the whole split; of the candidates, the
        // one drawing nearest 395 draws 406.8, wider than now.
        let (zone, context) = zone(
            span: 1900,
            floors: [225, 325, 325, 225, 375],
            weights: [nil, nil, nil, nil, nil]
        )
        let id = WindowID(2)
        #expect(zone.run(in: context) != nil)
        let drawn = width(id, zone, context)
        // The premise: the weight drawing nearest the length asked
        // draws the window wider.
        let line = zone.line(in: context)
        let nearest = try #require(
            zone.weightCandidates(
                for: id,
                at: drawn - 7,
                floor: line.bare[1],
                in: context
            )
            .map { zone.drawnLength(of: id, weight: $0, in: context) }
            .min { abs($0 - (drawn - 7)) < abs($1 - (drawn - 7)) }
        )
        try #require(nearest > drawn)
        let press = try #require(
            zone.press(id, by: -7, toward: .both, in: context)
        )
        #expect(press.weight != nil)
        #expect(press.refusal == nil)
        let after = applying(press, of: id, to: zone, in: context)
        #expect(width(id, zone, after) < drawn - 1)
    }

    @Test("A shrink no weight can take stops at the weight's limit")
    func shrinkNoWeightTakesStops() throws {
        // Every weight down to the floor draws the window wider once
        // the split flips.
        let (zone, context) = zone(
            span: 800,
            floors: [375, 350],
            weights: [0.1, 0.2]
        )
        let id = WindowID(2)
        #expect(zone.run(in: context) != nil)
        let press = try #require(
            zone.press(id, by: -60, toward: .both, in: context)
        )
        #expect(press.refusal == .atWeightLimit)
        #expect(press.cue == .ownMinimum)
        #expect(press.weight == nil)
    }

    @Test("A grow no weight can take pushes the mate")
    func growNoWeightTakesPushes() throws {
        // Window 1's weight can climb no higher than its mate's, and
        // every weight that flips the split draws it narrower.
        let (zone, context) = zone(
            span: 1000,
            floors: [375, 275],
            weights: [6, 10]
        )
        let id = WindowID(1)
        #expect(zone.run(in: context)?.hides == false)
        let drawn = width(id, zone, context)
        let press = try #require(
            zone.press(id, by: 110, toward: .both, in: context)
        )
        #expect(press.movesRun)
        #expect(press.visible == 0..<1)
        let after = applying(press, of: id, to: zone, in: context)
        #expect(width(id, zone, after) > drawn + 1)
    }

    /// Seed 674's state at its step 30 (#3634): window 2 holds a
    /// length, the run shows windows 2 to 4, and window 4 sits near
    /// its floor at `weight`.
    private func clampedRun(
        weight: Double
    ) -> (RunZone, LayoutContext) {
        var (zone, context) = zone(
            span: 1600,
            floors: [250, 200, 200, 300, 300],
            weights: [10, 1, 10, weight, 1]
        )
        context.runSizes = [
            WindowID(2): RunSize(share: 0.6102, zone: zone.ordinal),
            WindowID(5): RunSize(share: 0.4783, zone: zone.ordinal),
        ]
        context.runHeads = [WindowID(2)]
        context.runTails = [WindowID(4)]
        context.focused = WindowID(4)
        return (zone, context)
    }

    @Test("A clamped shrink answers as the weight's limit (#3634)")
    func clampedStepIsTheLimit() throws {
        let id = WindowID(4)
        let (zone, near) = clampedRun(weight: 0.10031)
        let floor = StackLayout.weightRange.lowerBound
        let (_, spent) = clampedRun(weight: floor)
        try #require(zone.run(in: near)?.visible == 1..<4)
        let drawn = width(id, zone, near)
        try #require(drawn > 300 && drawn < 302)
        let press = try #require(
            zone.press(id, by: -90, toward: .both, in: near)
        )
        let limit = try #require(
            zone.press(id, by: -90, toward: .both, in: spent)
        )
        #expect(press.weight == limit.weight)
        #expect(press.cue == limit.cue)
        #expect(press.refusal == limit.refusal)
        #expect(press.sizes.keys == limit.sizes.keys)
        let after = applying(press, of: id, to: zone, in: near)
        #expect(
            press.cue != nil
                || abs(width(id, zone, after) - drawn) > 0.5
                || zone.run(in: after)?.visible != 1..<4
        )
    }
}
