import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The plate slide on an explicit switch (#1956), driven through
/// the real `focus_space`: the incoming window's write is STAGED
/// until the strip lands, nothing animates with the engine on, and
/// the switch sends exactly the frames the instant switch sends —
/// the slide is drawn, never paid for in window moves. Every
/// window answers with an element of a pid nothing writes to (the
/// writer is inert), so a held write really stages. The panel and
/// the stack read are pinned inert by `makeTestCore`; the main
/// screen is the fixture's display, so a headless host skips
/// (#531).
@Suite("Plate slide switch (#1956)", .serialized)
@MainActor
struct SpaceSlideSwitchTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let w3 = WindowID(3)

    /// Windows 1 and 2 in Space 1, shown; window 3 in Space 2.
    private func makeCore(slide: Bool) throws -> (KiwiCore, WorkMeter) {
        let display = try #require(NSScreen.main?.kiwiDisplayID)
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1200, height: 775)
        }
        core.tiler.animation.isEnabled = false
        core.tiler.settings.animations.onSpaceChange = true
        core.spaceSlide.reduceMotion = { !slide }
        for (id, space) in [(w1, 1), (w2, 1), (w3, 2)] {
            core.state.apply(
                .windowCreated(ManagedWindow(id: id, pid: 1, appName: "A"))
            )
            core.state.workspaces.add(id, to: SpaceID(space))
        }
        for space in [1, 2] {
            core.state.workspaces.assign(SpaceID(space), to: display)
        }
        core.state.workspaces.activate(SpaceID(1))
        core.retile()
        try echo(core, [w1, w2, w3])
        // From here a switch that animated would start springs.
        core.tiler.animation.isEnabled = true
        let element = AXUIElementCreateApplication(1)
        core.tiler.applier.elementProvider = { _ in element }
        core.tiler.applier.writer = FrameWriter(
            setFrame: { _, _ in },
            setPosition: { _, _ in },
            writeEUI: { _, _ in }
        )
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        return (core, meter)
    }

    /// The AX echo of each window's last issued frame.
    private func echo(_ core: KiwiCore, _ ids: [WindowID]) throws {
        for id in ids {
            let frame = try #require(core.tiler.placements.recent(id))
            core.state.apply(.windowResized(id, frame))
        }
    }

    @Test(
        "the incoming window waits for the strip; nothing animates",
        .enabled(if: NSScreen.main != nil)
    )
    func incomingIsHeld() throws {
        let (core, _) = try makeCore(slide: true)
        core.execute("focus_space", args: [.string("2")])
        defer { core.spaceSlide.end() }
        #expect(core.spaceSlide.isPlaying)
        #expect(core.tiler.applier.held.isHeld(w3))
        #expect(core.tiler.applier.held.isStaged(w3))
        #expect(!core.tiler.applier.held.isHeld(w1))
        #expect(!core.tiler.applier.held.isStaged(w1))
        #expect(core.tiler.animation.activeCount == 0)
        // One page out, one in.
        #expect(core.spaceSlide.play?.pages.count == 2)
    }

    @Test(
        "under Reduce Motion the switch is instant",
        .enabled(if: NSScreen.main != nil)
    )
    func reduceMotionIsInstant() throws {
        let (core, _) = try makeCore(slide: false)
        core.execute("focus_space", args: [.string("2")])
        #expect(!core.spaceSlide.isPlaying)
        #expect(!core.tiler.applier.held.isHeld(w3))
    }

    @Test(
        "with the setting off the switch is instant",
        .enabled(if: NSScreen.main != nil)
    )
    func settingOffIsInstant() throws {
        let (core, _) = try makeCore(slide: true)
        core.tiler.settings.animations.onSpaceChange = false
        core.execute("focus_space", args: [.string("2")])
        #expect(!core.spaceSlide.isPlaying)
        #expect(!core.tiler.applier.held.isHeld(w3))
    }

    /// A display follow, a wake or a restore retiles through the
    /// same door with no intent: nothing on screen is navigation.
    @Test(
        "only an explicit switch plays",
        .enabled(if: NSScreen.main != nil)
    )
    func onlyNavigationPlays() throws {
        let (core, _) = try makeCore(slide: true)
        core.applyFocusedSpaceSwitch(to: SpaceID(2))
        #expect(!core.spaceSlide.isPlaying)
        #expect(!core.tiler.applier.held.isHeld(w3))
    }

    /// An instant switch inside a play ends it and sends what it
    /// held, or those windows would wait under no plate.
    @Test(
        "an instant switch overtaking a play releases its holds",
        .enabled(if: NSScreen.main != nil)
    )
    func instantSwitchReleasesHolds() throws {
        let (core, _) = try makeCore(slide: true)
        core.execute("focus_space", args: [.string("2")])
        try #require(core.tiler.applier.held.isHeld(w3))
        core.applyFocusedSpaceSwitch(to: SpaceID(1))
        #expect(!core.spaceSlide.isPlaying)
        #expect(!core.tiler.applier.held.isHeld(w3))
    }

    /// A follow's moved window is filed into the target while it is
    /// still on screen: it goes with the user, neither held nor
    /// left standing under a plate that slides away.
    @Test(
        "a window already on screen in the target is not held",
        .enabled(if: NSScreen.main != nil)
    )
    func shownTargetMemberIsNotHeld() throws {
        let (core, _) = try makeCore(slide: true)
        let moved = WindowID(4)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: moved,
                    pid: 1,
                    appName: "A",
                    frame: CGRect(x: 100, y: 100, width: 400, height: 300)
                )
            )
        )
        core.state.workspaces.add(moved, to: SpaceID(2))
        core.execute("focus_space", args: [.string("2")])
        defer { core.spaceSlide.end() }
        #expect(core.tiler.applier.held.isHeld(w3))
        #expect(!core.tiler.applier.held.isHeld(moved))
        // Nor plated: a plate would land over it, already there.
        let incoming = try #require(core.spaceSlide.play?.incoming)
        #expect(incoming.contains(w3))
        #expect(!incoming.contains(moved))
    }

    @Test(
        "a burst sends what the instant switch sends",
        .enabled(if: NSScreen.main != nil)
    )
    func slideCostsNoExtraWork() throws {
        var counts: [Bool: (WorkMeter.Counts, [WindowID: Int])] = [:]
        for slide in [false, true] {
            let (core, meter) = try makeCore(slide: slide)
            var issued: [WindowID: Int] = [:]
            core.tiler.applier.issued = { id, _ in issued[id, default: 0] += 1
            }
            for space in ["2", "1", "2"] {
                core.execute("focus_space", args: [.string(space)])
            }
            core.spaceSlide.end()
            core.tiler.applier.issued = { _, _ in }
            counts[slide] = (meter.snapshot(reset: false).counts, issued)
        }
        let instant = try #require(counts[false])
        let slide = try #require(counts[true])
        #expect(slide.0.parksIssued == instant.0.parksIssued)
        #expect(slide.0.parksSkipped == instant.0.parksSkipped)
        #expect(slide.1 == instant.1)
        #expect(!slide.1.isEmpty)
    }

    @Test(
        "a side Space Bar slides the strip vertically",
        .enabled(if: NSScreen.main != nil)
    )
    func sideBarSlidesVertically() throws {
        let (core, _) = try makeCore(slide: true)
        core.tiler.settings.spaceBarStyle.edge = .left
        core.execute("focus_space", args: [.string("2")])
        defer { core.spaceSlide.end() }
        #expect(core.spaceSlide.play?.axis == .vertical)
    }

    @Test(
        "a sticky window draws no plate",
        .enabled(if: NSScreen.main != nil)
    )
    func stickyDrawsNoPlate() throws {
        let (core, _) = try makeCore(slide: true)
        let sticky = WindowID(4)
        let frame = CGRect(x: 100, y: 100, width: 300, height: 300)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: sticky,
                    pid: 1,
                    appName: "A",
                    frame: frame,
                    stickyScope: .global
                )
            )
        )
        core.state.workspaces.add(sticky, to: SpaceID(1))
        let page = CGRect(x: -5000, y: -5000, width: 10_000, height: 10_000)
        let ids = core.slidePlates(of: SpaceID(1), stack: [:], in: page)
            .map(\.id)
        #expect(Set(ids) == [w1, w2])
    }

    @Test(
        "the plates' glass is the leaf through the gate",
        .enabled(if: NSScreen.main != nil)
    )
    func glassFollowsTheLeaf() throws {
        for on in [false, true] {
            let (core, _) = try makeCore(slide: true)
            core.tiler.settings.spaceSwitchLiquidGlass = on
            core.execute("focus_space", args: [.string("2")])
            #expect(
                core.spaceSlide.play?.glass
                    == LiquidGlassGate.rendered(glass: on)
            )
            core.spaceSlide.end()
        }
    }
}
