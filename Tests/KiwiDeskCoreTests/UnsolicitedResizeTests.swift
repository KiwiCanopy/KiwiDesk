import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A resize nobody asked for is corrected on its own event
/// (#1358): a zoomed tiled window goes back into its slot, a
/// zoomed effective float is fitted clear of the bars — through
/// the real `.windowResized` arm, with the two stand-downs that
/// keep the arm from fighting its own echoes or a mouse gesture.
@Suite("Unsolicited resize correction (#1358)", .serialized)
@MainActor
struct UnsolicitedResizeTests {
    private let w = WindowID(1)

    @MainActor
    private final class Applied {
        var frames: [WindowID: CGRect] = [:]
    }

    /// A monocle core whose issued frames land in `applied`,
    /// with every resize echo read as NOT our own ask's (the
    /// stamp only a real AX apply writes).
    private func makeCore(applied: Applied) -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1000, height: 800)
        }
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied.frames[id] = frame
        }
        core.tiler.echoGraceOverride = { _ in false }
        core.state.workspaces.setMode(SpaceID(1), .monocle)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w, pid: 1, appName: "App")
            )
        )
        return core
    }

    /// Places the window and settles it at its slot; returns
    /// the slot.
    private func settled(
        _ core: KiwiCore,
        applied: Applied
    ) throws -> CGRect {
        core.retile()
        let slot = try #require(applied.frames[w])
        core.state.apply(.windowResized(w, slot))
        applied.frames = [:]
        return slot
    }

    private static let corrected = "unsolicited resize"

    @Test("A zoomed tiled window is put back into its slot")
    func zoomedTiledWindowRetiles() throws {
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let slot = try settled(core, applied: applied)
        let zoomed = CGRect(x: 0, y: 0, width: 1000, height: 800)
        #expect(!TilingEngine.close(zoomed, to: slot))
        var log: [String] = []
        core.onLog = { log.append($0) }

        core.handle(.windowResized(w, zoomed))

        #expect(applied.frames[w] == slot)
        #expect(log.contains { $0.contains(Self.corrected) })
    }

    @Test("A resize inside the tolerance is left alone")
    func nearSlotResizeIsLeftAlone() throws {
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let slot = try settled(core, applied: applied)
        let nudged = slot.insetBy(dx: 1, dy: 1)

        core.handle(.windowResized(w, nudged))

        #expect(applied.frames[w] == nil)
    }

    @Test("Our own ask's echo is never corrected")
    func ownEchoStandsDown() throws {
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let slot = try settled(core, applied: applied)
        // The app answers our ask with a refused width: the
        // #677 channel, not a zoom. That channel probes on its
        // own (a candidate's second ask), so the frame sink
        // cannot tell the two apart — the log line can.
        core.tiler.echoGraceOverride = { _ in true }
        let refused = CGRect(
            origin: slot.origin,
            size: CGSize(width: 715, height: slot.height)
        )
        var log: [String] = []
        core.onLog = { log.append($0) }

        core.handle(.windowResized(w, refused))

        #expect(!log.contains { $0.contains(Self.corrected) })
    }

    /// Seeds a press at the slot's right edge, released now —
    /// the shape both a fast hand-drag's trailing event and an
    /// edge double-click's expand share; `clicks` tells them
    /// apart.
    private func edgePress(
        _ core: KiwiCore,
        slot: CGRect,
        clicks: Int
    ) {
        core.mouse.seedPress(
            at: CGPoint(x: slot.maxX, y: slot.midY),
            clickCount: clicks
        )
        // Stamped AHEAD: "released under a second ago" must hold
        // whatever the runner does between here and the event.
        core.mouse.seedRelease(at: Date().addingTimeInterval(60))
    }

    @Test("An edge double-click's expand is corrected, not dragged")
    func edgeDoubleClickIsCorrected() throws {
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let slot = try settled(core, applied: applied)
        edgePress(core, slot: slot, clicks: 2)
        var log: [String] = []
        core.onLog = { log.append($0) }

        core.handle(
            .windowResized(w, slot.insetBy(dx: -200, dy: 0))
        )

        #expect(applied.frames[w] == slot)
        #expect(log.contains { $0.contains(Self.corrected) })
    }

    @Test("A single click's trailing resize stays the drag's")
    func edgeSingleClickIsAGesture() throws {
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let slot = try settled(core, applied: applied)
        edgePress(core, slot: slot, clicks: 1)
        var log: [String] = []
        core.onLog = { log.append($0) }

        core.handle(
            .windowResized(w, slot.insetBy(dx: -200, dy: 0))
        )

        #expect(applied.frames[w] == nil)
        #expect(!log.contains { $0.contains(Self.corrected) })
    }

    @Test(
        "A zoomed float is fitted clear of the bar on its own event",
        .enabled(if: NSScreen.main != nil)
    )
    func zoomedFloatIsFitted() throws {
        // A Space Bar over a floating-mode space, the shape
        // `FloatingModeBarClampTests` paints: the zoom lands the
        // window under the strip, and the arm's retile carries
        // the #1178 sweep.
        let screen = try #require(NSScreen.main)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.tiler.echoGraceOverride = { _ in false }
        core.state.apply(.displaysChanged([display]))
        let settledFrame = CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY + 200,
            width: 400,
            height: 300
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: w,
                    pid: 1,
                    appName: "FloatApp",
                    frame: settledFrame
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = try #require(core.state.workspaces.space(of: w))
        core.state.workspaces.setMode(space, .floating)
        core.tiler.settings.spaceBarStyle.enabled = true
        core.tiler.settings.spaceBarStyle.edge = .top
        core.tiler.settings.spaceBarStyle.thickness = 40
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.updateSpaceBar()
        let strip = try #require(core.spaceBars.shownStrips.first?.1)
        var log: [String] = []
        core.onLog = { log.append($0) }

        let zoomed = CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY,
            width: 400,
            height: 300
        )
        core.handle(.windowResized(w, zoomed))

        let commanded = try #require(
            core.tiler.recentInstantTarget(w),
            "the zoomed float was never fitted"
        )
        #expect(commanded.minY >= strip.maxY)
        #expect(log.contains { $0.contains(Self.corrected) })
    }

    @Test("A float under no bar is left alone, however sized")
    func barlessFloatIsLeftAlone() throws {
        // The sweep would move nothing here — no painted strip —
        // so the arm must not retile and claim a correction. A
        // bsp space: monocle hosts an App Bar by default.
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        core.state.workspaces.setMode(SpaceID(1), .bsp)
        _ = try settled(core, applied: applied)
        #expect(core.appBars.shownStrips.isEmpty)
        #expect(core.spaceBars.shownStrips.isEmpty)
        let float = WindowID(2)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: float,
                    pid: 2,
                    appName: "Float",
                    frame: CGRect(x: 10, y: 10, width: 300, height: 200),
                    isFloating: true
                )
            )
        )
        applied.frames = [:]
        var log: [String] = []
        core.onLog = { log.append($0) }

        core.handle(
            .windowResized(
                float,
                CGRect(x: -50, y: -50, width: 1400, height: 1200)
            )
        )

        #expect(!log.contains { $0.contains(Self.corrected) })
    }

    @Test("A window no shown space places is left alone")
    func unshownSpaceMemberIsLeftAlone() throws {
        // One display, its shown space switched away: the layout
        // computes no frame for the window, and no frame is no
        // verdict. A second display's shown space IS placed —
        // `calculatedFrames` unions them — which a headless
        // fixture cannot show, since every fake display
        // resolves to the one host screen.
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        _ = try settled(core, applied: applied)
        core.state.workspaces.activate(SpaceID(2))
        applied.frames = [:]
        var log: [String] = []
        core.onLog = { log.append($0) }

        core.handle(
            .windowResized(
                w,
                CGRect(x: 0, y: 0, width: 1000, height: 800)
            )
        )

        #expect(applied.frames[w] == nil)
        #expect(!log.contains { $0.contains(Self.corrected) })
    }

    @Test("A deferred burst leaves the correction to its trailing pass")
    func deferralStandsTheCorrectionDown() throws {
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let slot = try settled(core, applied: applied)
        core.defersEventRetiles = true
        var log: [String] = []
        core.onLog = { log.append($0) }

        core.handle(
            .windowResized(
                w,
                CGRect(x: 0, y: 0, width: 1000, height: 800)
            )
        )

        #expect(applied.frames[w] == nil)
        #expect(!log.contains { $0.contains(Self.corrected) })
        core.defersEventRetiles = false
        core.retile()
        #expect(applied.frames[w] == slot)
    }

    @Test("An app that keeps reverting is corrected twice, then left")
    func revertingAppIsBounded() throws {
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let slot = try settled(core, applied: applied)
        let zoomed = CGRect(x: 0, y: 0, width: 1000, height: 800)
        var corrections = 0
        core.onLog = {
            if $0.contains(Self.corrected),
                !$0.contains("left standing")
            {
                corrections += 1
            }
        }
        // Each correction's ask is taken, then reverted past the
        // echo grace — every revert reads as unsolicited.
        for _ in 0..<4 {
            applied.frames = [:]
            core.handle(.windowResized(w, zoomed))
        }
        #expect(corrections == UnsolicitedResizeMemo.maxConsecutive)
        #expect(applied.frames[w] == nil)

        // Seen ON its frame again: the run ends and the memo
        // admits the next correction.
        core.handle(.windowResized(w, slot))
        applied.frames = [:]
        core.handle(.windowResized(w, zoomed))
        #expect(applied.frames[w] == slot)
        #expect(corrections == UnsolicitedResizeMemo.maxConsecutive + 1)
    }
}
