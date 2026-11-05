import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing
import os

@testable import KiwiDeskCore

/// What one fixed-size report does to the run it ends (#2994). Each
/// case stands the applier where production would leave it.
@Suite("A fixed-size report ends its run cleanly (#2994)")
@MainActor
struct FixedSizeReportTests {
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

    private func report(
        asked: CGSize = CGSize(width: 550, height: 400),
        serial: Int = 1,
        pressed: Bool = false
    ) -> FixedSizeReport {
        FixedSizeReport(
            window: WindowID(1),
            asked: asked,
            anchor: start,
            serial: serial,
            pressed: pressed
        )
    }

    private let asked = CGRect(x: 75, y: 100, width: 550, height: 400)

    /// A crossing ask's second write would put the ring back on it.
    @Test("A report drops the owed cross-screen resend")
    func resendIsDropped() async throws {
        let core = floatCore()
        _ = answering(core, .fixed)
        let id = WindowID(1)
        let applier = core.tiler.applier
        applier.applyInstant(id, asked, setSize: true, resend: true)
        core.handleFixedSize(report())
        #expect(applier.instantTarget(id) == nil)
        try await Task.sleep(for: .milliseconds(500))
        await drain()
        #expect(applier.instantTarget(id) == nil)
    }

    @Test("A newer move's resend is not the report's to drop")
    func moveResendStays() {
        let core = floatCore()
        _ = answering(core, .fixed)
        let id = WindowID(1)
        let applier = core.tiler.applier
        var owed: [@MainActor () -> Void] = []
        applier.scheduleResend = { _, work in owed.append(work) }
        let moved = start.offsetBy(dx: 40, dy: 0)
        applier.applyInstant(id, moved, setSize: true, resend: true)
        core.handleFixedSize(report())
        var issued = 0
        applier.issued = { _, _ in issued += 1 }
        #expect(owed.count == 1)
        owed.forEach { $0() }
        #expect(issued == 1)
    }

    @Test("A newer move's stamp is not the report's to clear")
    func moveStampStays() {
        let core = floatCore()
        _ = answering(core, .fixed)
        let id = WindowID(1)
        let applier = core.tiler.applier
        let moved = start.offsetBy(dx: 40, dy: 0)
        applier.applyInstant(id, moved, setSize: false)
        core.handleFixedSize(report())
        #expect(applier.instantTarget(id) == moved)
    }

    @Test("The cue names the axis the ask moved")
    func axisFollowsTheAsk() {
        let core = floatCore()
        _ = answering(core, .fixed)
        var axes: [String] = []
        core.borders.onResizeRefusal = { refusal in
            if case .ownMaximum(_, let axis, _) = refusal { axes.append(axis) }
        }
        core.handleFixedSize(report(asked: CGSize(width: 500, height: 460)))
        #expect(axes == ["y"])
    }

    /// Through the real hotkey fire, past `wireFixedSizeAnswer`.
    @Test("A hotkey press is what its report says it was")
    func hotkeyFireIsPressed() async throws {
        let f = try HoldGlideFixture(
            body: #"KiwiDesk.resize("x", 50)"#
        )
        f.seedFloating()
        f.core.execute(
            "animations.set_on_window_resize",
            args: [.bool(false)]
        )
        _ = answering(f.core, .fixed)
        var heard: [FixedSizeReport] = []
        f.core.tiler.applier.fixedSizeDoor.onReport = { heard.append($0) }
        f.registrar.press(keyCode: f.combo.keyCode)
        await drain()
        await drain()
        #expect(heard.map(\.pressed) == [true])
    }

    /// A slow app's report for the arming press lands past the
    /// key-repeat wait; a glide step's own report is no press (#3017).
    @Test("In a glide, a pressed report cues and a step's does not")
    func reportDuringGlide() throws {
        for pressed in [true, false] {
            let f = try HoldGlideFixture(
                body: #"KiwiDesk.resize("x", 50)"#
            )
            f.seedFloating()
            _ = answering(f.core, .free)
            var cues = 0
            f.core.borders.onResizeRefusal = { _ in cues += 1 }
            f.registrar.press(keyCode: f.combo.keyCode)
            try f.beginGlide()
            #expect(f.core.keys.isGliding)
            f.core.handleFixedSize(
                report(
                    serial: f.core.tiler.applier.fixedSizeDoor.serial + 1,
                    pressed: pressed
                )
            )
            #expect(cues == (pressed ? 1 : 0))
            #expect(!f.core.keys.isGliding)
        }
    }

    /// With animations on, every write is a spring tick after the fire.
    @Test(
        "A spring's writes carry the press that started it",
        .enabled(if: NSScreen.main != nil)
    )
    func springCarriesThePress() async throws {
        let f = try HoldGlideFixture(
            body: #"KiwiDesk.resize("x", 50)"#
        )
        f.seedFloating()
        _ = answering(f.core, .fixed)
        var heard: [FixedSizeReport] = []
        let applier = f.core.tiler.applier
        applier.fixedSizeDoor.onReport = { heard.append($0) }
        f.registrar.press(keyCode: f.combo.keyCode)
        let id = WindowID(1)
        #expect(f.core.tiler.animation.targetFrame(window: id) != nil)
        #expect(!f.core.keys.isFiring)
        applier.apply(id, asked, setSize: true)
        await drain()
        await drain()
        #expect(!heard.isEmpty)
        #expect(!heard.map(\.pressed).contains(false))
    }

    /// Read as the pill is asked for; the gate and the drawing's
    /// verdict are `RefusalCueSeamTests`'.
    @Test("A pressed report owes the funnel's sound, and only then")
    func soundFollowsThePress() {
        let core = floatCore()
        _ = answering(core, .fixed)
        var owed: [Bool] = []
        let door = core.tiler.applier.fixedSizeDoor
        core.borders.onResizeRefusal = { _ in
            owed.append(door.reportingPress)
        }
        core.handleFixedSize(report(serial: 1, pressed: true))
        #expect(!door.reportingPress)
        core.handleFixedSize(report(serial: 2, pressed: false))
        #expect(owed == [true, false])
    }
}
