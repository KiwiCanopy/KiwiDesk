import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing
import os

@testable import KiwiDeskCore

/// The real `resize` reaches `SizeLedWrite`, and its anchor lasts
/// only as long as its writes (#2981). An answering app is
/// wired under the applier, so these red on a lost call site where
/// `SizeLedWriteTests` cannot.
@Suite("A floating resize writes through its answer (#2981)")
@MainActor
struct SizeLedResizeWiringTests {
    private let start = CGRect(x: 100, y: 100, width: 500, height: 400)
    private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)

    private func answering(
        _ core: KiwiCore,
        _ kind: SizeLedApp.Kind
    ) -> SizeLedApp {
        let app = SizeLedApp(start, kind, screen: screen)
        let element = AXUIElementCreateApplication(getpid())
        let applier = core.tiler.applier
        core.tiler.elementProvider = { _ in element }
        applier.ownWindowMove = { _, _, _ in false }
        applier.writer = app.writer
        applier.screenFrames = { [screen] }
        return app
    }

    private func drain() async {
        await withCheckedContinuation { done in
            DispatchQueue.main.async { done.resume() }
        }
    }

    private func press(_ core: KiwiCore, _ axis: String, _ delta: Double) {
        core.execute(
            "resize",
            args: [.string(axis), .number(delta)]
        )
    }

    private func floatCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-sizeled-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { [screen] _ in screen }
        core.tiler.settings.animations.onWindowResize = false
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 900_001,
                    appName: "FloatApp",
                    frame: start,
                    isFloating: true
                )
            )
        )
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.state.workspaces.focus(WindowID(1), in: space)
        return core
    }

    @Test("A press on a fixed window moves nothing, in any order")
    func fixedPresses() async {
        let core = floatCore()
        let app = answering(core, .fixed)
        for (axis, delta) in [
            ("x", 50.0), ("y", 50), ("x", -50), ("y", -50), ("x", 50),
        ] {
            press(core, axis, delta)
            await drain()
            #expect(app.now == start)
        }
    }

    @Test("A press on a free window takes the symmetric split")
    func freePress() async {
        let core = floatCore()
        let app = answering(core, .free)
        press(core, "x", 50)
        await drain()
        #expect(
            app.now == CGRect(x: 75, y: 100, width: 550, height: 400)
        )
    }

    @Test("A glide on a fixed window never walks, past a boundary too")
    func fixedGlide() async throws {
        let f = try HoldGlideFixture(
            body: #"KiwiDesk.resize("x", 50)"#
        )
        f.seedFloating()
        f.core.execute(
            "animations.set_on_window_resize",
            args: [.bool(false)]
        )
        let app = answering(f.core, .fixed)
        f.registrar.press(keyCode: f.combo.keyCode)
        try f.beginGlide()
        await drain()
        // The commanded width runs until the region stops the hold,
        // past where the ask stopped moving its origin.
        var frames = 0
        while f.frameTick != nil, frames < 600 {
            try f.frame(1.0 / 60)
            frames += 1
            await drain()
            #expect(app.now == start)
        }
        #expect(frames > 1)
        #expect(try #require(f.commandedWidth()) > 700)
    }

    @Test("Any other engine frame ends the run")
    func otherFrameEnds() async {
        let core = floatCore()
        core.tiler.settings.animations.onWindowResize = true
        let app = answering(core, .fixed)
        let asked = CGRect(x: 75, y: 100, width: 550, height: 400)
        core.tiler.applier.sizeLedAnchors[WindowID(1)] = start
        core.tiler.applyFrame(
            WindowID(1),
            from: start,
            to: asked,
            animated: false
        )
        #expect(core.tiler.applier.sizeLedAnchors[WindowID(1)] == nil)
        await drain()
        #expect(app.now.minX == asked.minX)
    }

    @Test(
        "A spring carries the anchor and another frame ends it",
        .enabled(if: NSScreen.main != nil)
    )
    func animatedFrameEnds() async {
        let core = floatCore()
        _ = answering(core, .fixed)
        let id = WindowID(1)
        let asked = CGRect(x: 75, y: 100, width: 550, height: 400)
        core.tiler.applyFrame(
            id,
            from: start,
            to: asked,
            animated: true,
            sizeLedFrom: start
        )
        #expect(core.tiler.applier.sizeLedAnchors[id] == start)
        core.tiler.applyFrame(id, from: start, to: asked, animated: true)
        #expect(core.tiler.applier.sizeLedAnchors[id] == nil)
        core.tiler.animation.cancelAll(snapToTargets: false)
        await drain()
    }

    @Test("A write the hold stages keeps its anchor to the landing")
    func heldWriteKeepsTheAnchor() async throws {
        let core = floatCore()
        let app = answering(core, .fixed)
        let applier = core.tiler.applier
        let id = WindowID(1)
        applier.holdWrites([id], until: .now() + 0.05)
        applier.sizeLedAnchors[id] = start
        applier.applyInstant(
            id,
            CGRect(x: 75, y: 100, width: 550, height: 400),
            setSize: true
        )
        // A generous guard, never a tight deadline (#344).
        for _ in 0..<500 where app.writes.withLock({ $0.isEmpty }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        await drain()
        #expect(!app.writes.withLock { $0.isEmpty })
        #expect(app.now == start)
    }

    /// A window at its maximum takes #2973's probe and refuses the
    /// grow the judge then writes, so that write leads too.
    @Test("The judge's asked size does not walk a window at its maximum")
    func judgeWriteLeads() async {
        let core = floatCore()
        let app = answering(core, .atMaximum)
        core.windowServer.readWindowBounds = { [start] _ in
            CGRect(origin: start.origin, size: CGSize(width: 488, height: 400))
        }
        core.judgeFloatAspectProbe(
            KiwiCore.FloatAspectAsk(
                window: WindowID(1),
                axis: "x",
                delta: 50,
                base: start,
                target: CGRect(x: 75, y: 100, width: 550, height: 400)
            ),
            live: start
        )
        await drain()
        #expect(!app.writes.withLock { $0.isEmpty })
        #expect(app.now.origin == start.origin)
    }

    /// The newest write says whether it leads, whatever waited.
    @Test("A led write merged over a staged one keeps its anchor")
    func heldMergeTakesTheNewerLead() async throws {
        let core = floatCore()
        let app = answering(core, .fixed)
        let applier = core.tiler.applier
        let id = WindowID(1)
        let asked = CGRect(x: 75, y: 100, width: 550, height: 400)
        applier.holdWrites([id], until: .now() + 0.05)
        applier.applyInstant(id, start, setSize: true)
        applier.sizeLedAnchors[id] = start
        applier.applyInstant(id, asked, setSize: true)
        // A generous guard, never a tight deadline (#344).
        for _ in 0..<500 where app.writes.withLock({ $0.isEmpty }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        await drain()
        #expect(!app.writes.withLock { $0.isEmpty })
        #expect(app.now == start)
    }

    /// Its own target's origin is what the app may have refused.
    @Test(
        "A press on the resize's own spring keeps that spring's anchor",
        .enabled(if: NSScreen.main != nil)
    )
    func pressOnItsOwnSpring() {
        let core = floatCore()
        core.tiler.settings.animations.onWindowResize = true
        _ = answering(core, .fixed)
        press(core, "x", 50)
        press(core, "x", 50)
        #expect(core.tiler.applier.sizeLedAnchors[WindowID(1)] == start)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test(
        "A press on another spring anchors where that spring lands",
        .enabled(if: NSScreen.main != nil)
    )
    func pressOnAMoveSpring() {
        let core = floatCore()
        core.tiler.settings.animations.onWindowResize = true
        _ = answering(core, .fixed)
        let id = WindowID(1)
        let moved = start.offsetBy(dx: 200, dy: 40)
        core.tiler.applyFrame(id, from: start, to: moved, animated: true)
        press(core, "x", 50)
        #expect(
            core.tiler.applier.sizeLedAnchors[id]
                == CGRect(origin: moved.origin, size: start.size)
        )
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// A held chord's first glide frame cancels its press's spring.
    @Test(
        "An instant frame that cancels a spring keeps its anchor",
        .enabled(if: NSScreen.main != nil)
    )
    func instantAfterSpring() async {
        let core = floatCore()
        let app = answering(core, .fixed)
        let id = WindowID(1)
        let asked = CGRect(x: 75, y: 100, width: 550, height: 400)
        core.tiler.applyFrame(
            id,
            from: start,
            to: asked,
            animated: true,
            sizeLedFrom: start
        )
        core.tiler.applyFrame(
            id,
            from: start,
            to: asked,
            animated: false,
            sizeLedFrom: start
        )
        await drain()
        #expect(app.now == start)
    }

    @Test("An instant write spends its anchor, a spring keeps it to the end")
    func anchorLifetime() async {
        let core = floatCore()
        let app = answering(core, .fixed)
        let applier = core.tiler.applier
        let id = WindowID(1)
        let asked = CGRect(x: 75, y: 100, width: 550, height: 400)

        applier.sizeLedAnchors[id] = start
        applier.applyInstant(id, asked, setSize: true)
        #expect(applier.sizeLedAnchors[id] == nil)
        await drain()
        #expect(app.now == start)

        applier.beginAnimating(id)
        applier.sizeLedAnchors[id] = start
        applier.apply(id, asked, setSize: true)
        #expect(applier.sizeLedAnchors[id] == start)
        await drain()
        #expect(app.now == start)
        applier.endAnimating(id)
        #expect(applier.sizeLedAnchors[id] == nil)
    }

    @Test("A cross-screen set's second write keeps the anchor")
    func resendKeepsTheAnchor() async {
        let core = floatCore()
        let app = answering(core, .fixed)
        let applier = core.tiler.applier
        var owed: [@MainActor () -> Void] = []
        applier.scheduleResend = { _, work in owed.append(work) }
        applier.sizeLedAnchors[WindowID(1)] = start
        applier.applyInstant(
            WindowID(1),
            CGRect(x: 75, y: 100, width: 550, height: 400),
            setSize: true,
            resend: true
        )
        await drain()
        #expect(owed.count == 1)
        owed.forEach { $0() }
        await drain()
        #expect(app.now == start)
    }
}
