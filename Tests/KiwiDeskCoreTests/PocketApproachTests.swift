import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket's resting handle joins the revealer's approach (#3368):
/// a hover lights the tab in place (#3366), lingering near it rises
/// the pocket as a countdown, a rest on the tab hurries the rise from
/// where it stands, and a leave sinks it back. The revealer's clock,
/// pointer and timers are the suite's own (tests.md ▸ the
/// age-bounded ledger rule).
@Suite(
    "Pocket approach (#3368)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketApproachTests {
    typealias Fixture = ShelfRevealerTests

    @MainActor private struct Rig {
        let core: KiwiCore
        let timers: Fixture.Timers
        let pointer: Fixture.Box
        let display: DisplayID

        var key: ShelfRevealer.Key { core.pocketApproachKey(on: display) }
        var target: ShelfRevealer.Target? {
            core.shelves.reveal.targets[key]
        }
        var spec: PocketPlateOverlay.Spec? {
            core.pocketPlate.specs[display]
        }

        /// Files the handle's approach and draws the pocket.
        func pass() {
            var hiding = KiwiCore.HidingShelves()
            core.filePocketApproaches(into: &hiding)
            core.shelves.reveal.sync(hiding.targets)
            core.updatePocketPlate(slots: [:])
        }

        func move(to point: CGPoint) {
            pointer.point = point
            core.shelves.reveal.moved(to: point)
            pass()
        }
    }

    private func rig(visibility: String = "auto") throws -> Rig {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-approach-\(UUID().uuidString)")
        )
        let screen = try #require(NSScreen.main)
        let id = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: id)
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.execute(
            "kiwishelf.set_pocket_visibility",
            args: [.string(visibility)]
        )
        pinRevealLength()
        let timers = Fixture.Timers()
        let pointer = Fixture.Box()
        let reveal = core.shelves.reveal
        reveal.onChange = {}
        reveal.location = { pointer.point }
        reveal.macEdges = { pointer.edges }
        reveal.now = { pointer.now }
        reveal.schedule = { delay, body in
            let index = timers.queue.count
            timers.queue.append((delay, body, true))
            return ShelfRevealTimer(onCancel: {
                if index < timers.queue.count {
                    timers.queue[index].live = false
                }
            })
        }
        let rig = Rig(
            core: core,
            timers: timers,
            pointer: pointer,
            display: id
        )
        rig.pass()
        return rig
    }

    private func depth(_ spec: PocketPlateOverlay.Spec) -> CGFloat {
        spec.handle?.isHorizontal == false
            ? spec.frame.width : spec.frame.height
    }

    /// A point in the approach, off the tab and the edge's last row.
    private func nearTab(_ target: ShelfRevealer.Target) throws -> CGPoint {
        let approach = try #require(target.approach)
        let tab = try #require(target.handle)
        let row = try #require(target.edgeRow)
        let points = stride(from: 0.05, to: 1, by: 0.05).flatMap { u in
            stride(from: 0.05, to: 1, by: 0.05).map { v in
                CGPoint(
                    x: approach.minX + u * approach.width,
                    y: approach.minY + v * approach.height
                )
            }
        }
        return try #require(
            points.first { !tab.contains($0) && !row.contains($0) }
        )
    }

    private func onTab(_ target: ShelfRevealer.Target) throws -> CGPoint {
        let tab = try #require(target.handle)
        return CGPoint(x: tab.midX, y: tab.midY)
    }

    @Test("a hover lights the tab in place and rises nothing")
    func hoverLightsInPlace() throws {
        let rig = try rig()
        let rest = try #require(rig.spec)
        rig.core.pocketHovered(rest.display, true)
        let lit = try #require(rig.spec)
        #expect(lit.hovered)
        #expect(!lit.risen)
        #expect(lit.frame == rest.frame)
        let view = try #require(rig.core.pocketPlate.view(on: rest.display))
        #expect(view.handle.hovered)
    }

    @Test("lingering near the tab rises the pocket as its countdown")
    func approachRises() throws {
        let rig = try rig()
        let rest = try #require(rig.spec)
        let target = try #require(rig.target)
        // Across the band alone, never past its ends.
        let approach = try #require(target.approach)
        let tab = try #require(target.handle)
        #expect(
            rest.handle?.isHorizontal == false
                ? approach.height == tab.height
                : approach.width == tab.width
        )
        rig.move(to: try nearTab(target))
        let fill = try #require(rig.core.shelves.reveal.fills[rig.key])
        #expect(abs(fill.length - ShelfReveal.dwellDelay) < 1e-6)
        let rising = try #require(rig.spec)
        #expect(!rising.risen)
        if BarMotion.pocketScrubs {
            #expect(rising.rise == fill)
            // The rise needs the risen pocket's room.
            #expect(depth(rising) > depth(rest))
        }
        rig.timers.fireAll()
        rig.pass()
        let risen = try #require(rig.spec)
        #expect(risen.risen)
        #expect(risen.rise == nil)
    }

    @Test("an entry on the tab rises in the reveal delay")
    func tabEntryRises() throws {
        let rig = try rig()
        rig.move(to: try onTab(try #require(rig.target)))
        let fill = try #require(rig.core.shelves.reveal.fills[rig.key])
        #expect(abs(fill.length - ShelfReveal.revealDelay) < 1e-6)
        #expect(PocketRiseTimeline.delay(of: fill) == 0)
    }

    @Test("moving onto the tab hurries the rise from where it stands")
    func tabHurries() throws {
        let rig = try rig()
        let target = try #require(rig.target)
        rig.move(to: try nearTab(target))
        // 0.1 s into its 0.25 s rise: 40 % up.
        rig.pointer.now += ShelfReveal.revealDelay + 0.1
        rig.move(to: try onTab(target))
        let fill = try #require(rig.core.shelves.reveal.fills[rig.key])
        #expect(fill.started == rig.pointer.now)
        #expect(abs(fill.length - 0.6 * PocketRiseTimeline.fastSpan) < 1e-6)
        #expect(rig.timers.delays.contains { abs($0 - fill.length) < 1e-6 })
    }

    @Test("a leave sinks the rise in its risen room, then rests")
    func leaveSinks() throws {
        let rig = try rig()
        var landings: [() -> Void] = []
        rig.core.pocketPlate.afterLeave = { _, body in landings.append(body) }
        let rest = try #require(rig.spec)
        rig.move(to: try nearTab(try #require(rig.target)))
        let view = try #require(rig.core.pocketPlate.view(on: rig.display))
        let risenSize = view.frame.size
        rig.move(to: CGPoint(x: -10_000, y: -10_000))
        let left = try #require(rig.spec)
        #expect(left.rise == nil)
        #expect(!left.risen)
        #expect(left.frame == rest.frame)
        guard BarMotion.pocketScrubs else { return }
        // The sink runs in the room it rose in, its landing gives it
        // back.
        #expect(view.sinking)
        #expect(view.frame.size == risenSize)
        #expect(landings.count == 1)
        landings.forEach { $0() }
        #expect(!view.sinking)
        #expect(view.frame.size == rest.frame.size)
    }

    @Test("the panel hands its own moves to the revealer")
    func viewIsWired() throws {
        let rig = try rig()
        let view = try #require(rig.core.pocketPlate.view(on: rig.display))
        view.updateTrackingAreas()
        #expect(
            view.trackingAreas.contains { $0.options.contains(.mouseMoved) }
        )
        let point = try nearTab(try #require(rig.target))
        rig.pointer.point = point
        view.onMove(point)
        #expect(rig.core.shelves.reveal.fills[rig.key] != nil)
        view.setHovered(true)
        #expect(rig.spec?.hovered == true)
    }

    @Test("an empty pocket fades its kiwis, the tab stays")
    func kiwisFade() throws {
        let rig = try rig()
        let rest = try #require(rig.spec)
        #expect(rest.faded)
        let view = try #require(rig.core.pocketPlate.view(on: rig.display))
        #expect(view.window?.alphaValue == 1)
        #expect(view.handle.faded)
        #expect(view.pocket.alphaValue == PocketPlateOverlay.fadedAlpha)
        // A hover shows it full.
        rig.core.pocketHovered(rest.display, true)
        #expect(!view.handle.faded)
        #expect(view.pocket.alphaValue == 1)
    }

    @Test("the whole mark keeps its empty fade")
    func wholeMarkFades() throws {
        let rig = try rig(visibility: "always")
        let rest = try #require(rig.spec)
        #expect(rest.whole)
        let view = try #require(rig.core.pocketPlate.view(on: rig.display))
        #expect(view.window?.alphaValue == PocketPlateOverlay.fadedAlpha)
        #expect(!view.handle.faded)
        // The whole mark files no approach.
        #expect(rig.target == nil)
    }

    @Test("the hovered tab takes the fill strength, the kiwis stay")
    func tabStrength() {
        let light = NSAppearance(named: .aqua)
        var rest: CGFloat = 0
        var full: CGFloat = 0
        light?.performAsCurrentDrawingAppearance {
            rest =
                PocketHandleView.tabCore(hex: "", hovered: false)
                .alphaComponent
            full =
                PocketHandleView.tabCore(hex: "", hovered: true)
                .alphaComponent
        }
        #expect(abs(rest - ShelfHandleSpec.restStrength) < 0.001)
        #expect(abs(full - ShelfHandleSpec.fillStrength) < 0.001)
    }
}
