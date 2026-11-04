import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// What every press along a run keeps, whatever came before it
/// (#2709): seeded press sequences over zones of mixed floors, each
/// answer stored and persisted as the writers do, the invariants read
/// off the frames the render draws. Pure; a failure names its seed and
/// step, so it replays.
@Suite("Run zone press properties (#2709)")
struct RunZonePressPropertyTests {
    /// A small deterministic generator, so a failure replays.
    private struct Seeded {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state =
                state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(bound))
        }
    }

    private func start(
        _ random: inout Seeded
    ) -> (zone: RunZone, context: LayoutContext, floors: [CGFloat]) {
        let count = 2 + random.next(5)
        let ids = (1...count).map { WindowID(UInt32($0)) }
        let span = CGFloat(800 + random.next(13) * 100)
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
        var floors: [CGFloat] = []
        for id in ids {
            let floor = CGFloat(200 + random.next(4) * 50)
            floors.append(floor)
            context.sizeBounds[id] = EffectiveSizeBound(width: [
                .init(asked: 50, answered: floor)
            ])
        }
        return (zone, context, floors)
    }

    /// `press` stored as the writers store it, then one pass's persist.
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
        return persisted(zone, after)
    }

    private func persisted(
        _ zone: RunZone,
        _ context: LayoutContext
    ) -> LayoutContext {
        var after = context
        let run = zone.run(in: context)
        let hides = run?.hides == true
        let sized = hides ? zone.sizedMembers(in: context) : []
        after.runSizes = context.runSizes.filter { sized.contains($0.key) }
        let visible =
            hides
            ? run?.visible ?? zone.members.indices
            : zone.members.indices
        (after.runHeads, after.runTails) = zone.ends(
            showing: visible,
            heads: context.runHeads,
            tails: context.runTails
        )
        return after
    }

    @Test("Every press keeps the run whole and its step honest")
    func pressesKeepTheInvariants() throws {
        for seed in 1...300 {
            var random = Seeded(state: UInt64(seed))
            var (zone, context, _) = start(&random)
            context = persisted(zone, context)
            for step in 0..<40 {
                let note = Comment(rawValue: "seed \(seed) step \(step)")
                let before =
                    zone.run(in: context)?.visible
                    ?? zone.members.indices
                let at = before.lowerBound + random.next(before.count)
                let id = zone.members[at]
                context.focused = id
                let delta = CGFloat(random.next(61) - 30) * 10
                guard delta != 0 else { continue }
                let side: RunZone.PushSide =
                    [.start, .end, .both][random.next(3)]
                let drawn = zone.frames(in: context)[id]?.width ?? 0
                guard
                    let press = zone.press(
                        id,
                        by: delta,
                        toward: side,
                        in: context
                    )
                else { continue }
                context = applying(press, of: id, to: zone, in: context)
                let after =
                    zone.run(in: context)?.visible
                    ?? zone.members.indices
                let frames = zone.frames(in: context)
                // The writer's run is the run the render draws.
                if let planned = press.visible {
                    #expect(after == planned, note)
                }
                // Shown windows fill the zone, in order, with no hole.
                let gap = context.gaps.inner.horizontal
                var edge: CGFloat = 0
                for index in after {
                    let frame = try #require(frames[zone.members[index]])
                    #expect(abs(frame.minX - edge) < 1, note)
                    edge = frame.maxX + gap
                }
                #expect(abs(edge - gap - zone.region.width) < 1, note)
                // A press hides or shows nothing against its sense.
                if delta > 0 {
                    #expect(
                        after.allSatisfy { before.contains($0) },
                        note
                    )
                }
                if delta < 0 {
                    #expect(
                        before.allSatisfy { after.contains($0) },
                        note
                    )
                }
                // The pressed window stays shown and moves the right way.
                #expect(after.contains(at), note)
                let now = frames[id]?.width ?? 0
                if delta > 0 { #expect(now >= drawn - 1, note) }
                if delta < 0 { #expect(now <= drawn + 1, note) }
            }
        }
    }
}
