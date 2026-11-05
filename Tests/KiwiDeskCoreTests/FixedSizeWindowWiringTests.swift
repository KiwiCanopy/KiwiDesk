import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing
import os

@testable import KiwiDeskCore

/// A write that finds macOS says its window cannot be sized ends its
/// run with a true cue, and an app that only answers short keeps
/// climbing (#2994). Spends the main actor on 60 glide frames at most.
@Suite("A fixed-size window's asks do not climb (#2994)")
@MainActor
struct FixedSizeWindowWiringTests {
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

    private func refusals(_ core: KiwiCore) -> () -> [ResizeRefusal] {
        var seen: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { seen.append($0) }
        return { seen }
    }

    @Test("Every press on a fixed window draws the app's limit, at any pace")
    func fixedPressesCue() async {
        let core = floatCore()
        let app = answering(core, .fixed)
        let seen = refusals(core)
        for (n, delta) in [50.0, -50, 50].enumerated() {
            press(core, "x", delta)
            await drain()
            await drain()
            #expect(app.now == start)
            #expect(seen().count == n + 1)
        }
        guard seen().count >= 2 else { return }
        guard case .ownMaximum(_, _, atBoundary: false) = seen()[0] else {
            Issue.record("expected the app's own maximum")
            return
        }
        guard case .ownMinimum(_, _, appBound: true) = seen()[1] else {
            Issue.record("expected the app's own minimum")
            return
        }
        #expect(core.tiler.applier.instantTarget(WindowID(1)) == nil)
    }

    /// The controls: each answers short or takes the size, and macOS
    /// says each can be sized.
    @Test("A window macOS says can be sized is never read as fixed")
    func settableNeverCues() async {
        for kind: SizeLedApp.Kind in [.free, .fixedWidth, .ratio, .atMaximum] {
            let core = floatCore()
            _ = answering(core, kind)
            let seen = refusals(core)
            press(core, "x", 50)
            await drain()
            await drain()
            #expect(seen().isEmpty)
        }
    }

    /// A real frame through the writer: an arm hand-fed its report
    /// could not see a spring that no longer ends.
    @Test(
        "A spring's first report ends it, and the rest repeat nothing",
        .enabled(if: NSScreen.main != nil)
    )
    func springEndsOnce() async {
        let core = floatCore()
        core.tiler.settings.animations.onWindowResize = true
        _ = answering(core, .fixed)
        let seen = refusals(core)
        let id = WindowID(1)
        let asked = CGRect(x: 75, y: 100, width: 550, height: 400)
        press(core, "x", 50)
        #expect(core.tiler.animation.targetFrame(window: id) != nil)
        core.tiler.applier.apply(id, asked, setSize: true)
        core.tiler.applier.apply(id, asked, setSize: true)
        await drain()
        await drain()
        await drain()
        #expect(core.tiler.animation.targetFrame(window: id) == nil)
        #expect(seen().count == 1)
    }

    private func report(serial: Int, pressed: Bool = false) -> FixedSizeReport
    {
        FixedSizeReport(
            window: WindowID(1),
            asked: CGSize(width: 550, height: 400),
            anchor: start,
            serial: serial,
            pressed: pressed
        )
    }

    /// A press from rest has no record to read, so a window that has
    /// become sizable simply takes the next ask.
    @Test("A report leaves nothing behind for the next press")
    func nothingIsKept() async {
        let core = floatCore()
        let app = answering(core, .free)
        let seen = refusals(core)
        core.handleFixedSize(report(serial: 1))
        #expect(seen().count == 1)
        press(core, "x", 50)
        await drain()
        await drain()
        #expect(app.now.width == 550)
        #expect(seen().count == 1)
    }

    @Test("A write already out when the cue drew does not cue again")
    func oldReportsRepeatNothing() {
        let core = floatCore()
        _ = answering(core, .fixed)
        let seen = refusals(core)
        let door = core.tiler.applier.fixedSizeDoor
        door.serial = 5
        core.handleFixedSize(report(serial: 3))
        core.handleFixedSize(report(serial: 4))
        core.handleFixedSize(report(serial: 5))
        #expect(seen().count == 1)
        door.serial = 6
        core.handleFixedSize(report(serial: 6))
        #expect(seen().count == 2)
    }

    @Test("A report for a window no longer focused draws nothing")
    func otherWindowIsLeftAlone() {
        let core = floatCore()
        _ = answering(core, .fixed)
        let seen = refusals(core)
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(2),
                    pid: 900_001,
                    appName: "FloatApp",
                    frame: start,
                    isFloating: true
                )
            )
        )
        core.state.workspaces.focus(WindowID(2), in: space)
        core.handleFixedSize(report(serial: 1))
        #expect(seen().isEmpty)
    }

    @Test("A call no hotkey fired reports no press, in write order")
    func callIsNoPress() async {
        let core = floatCore()
        _ = answering(core, .fixed)
        var heard: [FixedSizeReport] = []
        let door = core.tiler.applier.fixedSizeDoor
        door.onReport = { heard.append($0) }
        press(core, "x", 50)
        press(core, "x", 50)
        await drain()
        await drain()
        #expect(heard.map(\.pressed) == [false, false])
        guard heard.count == 2 else { return }
        #expect(heard[0].serial < heard[1].serial)
    }

    @Test("A report ends the ask macOS has answered, not a written probe")
    func judgementEnds() {
        let core = floatCore()
        _ = answering(core, .fixed)
        let id = WindowID(1)
        core.state.floatAspectFlight = .asking(id, axis: "x", grows: true)
        core.handleFixedSize(report(serial: 1))
        #expect(core.state.floatAspectFlight == nil)
        core.state.floatAspectFlight = .probing(id)
        core.endFloatAspectAsk(of: id)
        #expect(core.state.floatAspectFlight == .probing(id))
    }

    private func reports(
        _ kind: SizeLedApp.Kind,
        anchor: CGRect,
        asked: CGRect,
        setSize: Bool = true,
        seed: CGRect? = nil
    ) -> Int {
        let app = SizeLedApp(seed ?? anchor, kind, screen: screen)
        let count = OSAllocatedUnfairLock(initialState: 0)
        SizeLedWrite.Lead(
            anchor: anchor,
            screens: [screen],
            fixed: { _ in count.withLock { $0 += 1 } }
        ).write(
            asked,
            AXUIElementCreateApplication(getpid()),
            setSize,
            nil,
            app.writer
        )
        return count.withLock { $0 }
    }

    /// A 408-high grid answers a sub-row ask with its old height.
    @Test("Only macOS's statement reports, never a short answer")
    func onlyTheStatementReports() {
        let tall = CGRect(x: 100, y: 100, width: 500, height: 408)
        let taller = CGRect(x: 100, y: 98, width: 500, height: 413)
        #expect(reports(.grid, anchor: tall, asked: taller) == 0)
        #expect(reports(.fixed, anchor: tall, asked: taller) == 1)
        #expect(reports(.free, anchor: tall, asked: taller) == 0)
        // An answer away from the anchor asks macOS nothing.
        let stale = tall.offsetBy(dx: 0, dy: 0).insetBy(dx: 0, dy: 20)
        #expect(reports(.fixed, anchor: stale, asked: taller, seed: tall) == 0)
        // A spring's position-only frame asks no size.
        #expect(
            reports(.fixed, anchor: tall, asked: taller, setSize: false) == 0
        )
        // Nor does an ask within a point of the window.
        let same = CGRect(x: 100, y: 100, width: 500.5, height: 408)
        #expect(reports(.fixed, anchor: tall, asked: same) == 0)
    }

    /// The report lands in the key-repeat wait, ahead of the glide.
    @Test("A hold on a fixed window ends in its wait, with one cue")
    func fixedHoldEnds() async throws {
        let f = try HoldGlideFixture(
            body: #"KiwiDesk.resize("x", 50)"#
        )
        f.seedFloating()
        f.core.execute(
            "animations.set_on_window_resize",
            args: [.bool(false)]
        )
        let app = answering(f.core, .fixed)
        let seen = refusals(f.core)
        f.registrar.press(keyCode: f.combo.keyCode)
        await drain()
        await drain()
        #expect(seen().count == 1)
        #expect(f.core.keys.holdGlide.heldID == nil)
        #expect(app.now == start)
    }

    /// The residue: macOS calls this window sizable, so its asks climb
    /// and only the origin is the write's to hold.
    @Test("A glide past a window's maximum never walks its origin")
    func maximumGlideHolds() async throws {
        let f = try HoldGlideFixture(
            body: #"KiwiDesk.resize("x", 50)"#
        )
        f.seedFloating()
        f.core.execute(
            "animations.set_on_window_resize",
            args: [.bool(false)]
        )
        let app = answering(f.core, .atMaximum)
        f.registrar.press(keyCode: f.combo.keyCode)
        try f.beginGlide()
        await drain()
        var frames = 0
        while f.frameTick != nil, frames < 60 {
            try f.frame(1.0 / 60)
            frames += 1
            await drain()
            #expect(app.now == start)
        }
        #expect(frames > 1)
    }
}
