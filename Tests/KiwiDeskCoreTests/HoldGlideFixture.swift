import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The shared PRODUCTION fixture for hold-to-glide
/// (#1056/#1082): a real `KiwiCore`, a real Lua binding body, a
/// real release-reporting registrar — only the pre-glide wait and
/// the frame clock are captured, so a frame reaches the real
/// `resize`. Its own file because three suites drive it —
/// `HoldGlideWiringTests`, `HoldGlideRefusalWiringTests` and
/// `FloatGlideAccumulationTests` — split at §2.1's ceiling rather
/// than after crossing it.
///
/// It is on tests.md's ratified shared-helper list, admitted on
/// the DIVERGENCE ground: what it shares is a live `KiwiCore`
/// wired so that a driven frame reaches the real `resize`, and a
/// copy that stubbed one seam more (`applyGlideStep` is
/// deliberately NOT stubbed) would leave its suite reading the
/// ladder instead of the feature, while staying green. Its state
/// is per-instance — each test builds its own — so nothing is
/// carried between tests.
@MainActor
final class HoldGlideFixture {
    let core: KiwiCore
    let registrar: ReleaseRegistrar
    let combo: KeyCombo
    var ticks: [(delay: TimeInterval, work: () -> Void)] =
        []
    var frameTick: ((TimeInterval) -> Void)?

    init(body: String) throws {
        registrar = ReleaseRegistrar()
        core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-holdwire-\(UUID().uuidString)"
                ),
            hotkeyRegistrar: registrar
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        combo = try #require(KeyCombo.parse("ctrl+alt+l"))
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        let config = """
            KiwiDesk.bind("ctrl+alt+l", function()
                hits = (hits or 0) + 1
                \(body)
            end)
            KiwiDesk.define_layer("r", {
                h = function() end,
            })
            """
        try config.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        core.keys.holdGlide.initialDelay = { 0.5 }
        core.keys.holdGlide.schedule = {
            [weak self] delay, work in
            self?.ticks.append((delay, work))
            return {}
        }
        // The live seam is a `CADisplayLink` on a real
        // screen; capture the callback instead and drive
        // frames by hand. `applyGlideStep` is deliberately
        // NOT stubbed — the whole point of this suite is
        // that a frame reaches the real `resize`.
        core.keys.holdGlide.startFrames = {
            [weak self] tick in
            self?.frameTick = tick
            return { self?.frameTick = nil }
        }
    }

    /// Two tiled windows in bsp on one space, window 1
    /// focused, so `resize` succeeds and moves the ratio.
    func seedBspPair() {
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(
            of: WindowID(1)
        )!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("bsp")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
    }

    /// One FLOATING window, focused, so `resize` takes the
    /// `resizeFloating` path (#1090) instead of a layout ratio —
    /// the path that measures from a FRAME and so needs a
    /// commanded base at frame rate. Takes an id so a suite can
    /// seed it BESIDE `seedBspPair`, which is what the stale-
    /// record case needs: an arming press on a tiled window and
    /// a focus change onto the float mid-hold.
    func seedFloating(id: UInt32 = 1) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(id),
                    pid: pid_t(id),
                    appName: "FloatApp",
                    frame: CGRect(
                        x: 100,
                        y: 100,
                        width: 500,
                        height: 400
                    ),
                    isFloating: true
                )
            )
        )
        let space = core.state.workspaces.space(
            of: WindowID(id)
        )!
        core.state.workspaces.focus(WindowID(id), in: space)
    }

    /// Focus `id` in its own space, for a focus change mid-hold.
    func focus(_ id: UInt32) {
        let window = WindowID(id)
        let space = core.state.workspaces.space(of: window)!
        core.state.workspaces.focus(window, in: space)
    }

    /// The width a window was last COMMANDED to, read off the
    /// store under test rather than off the #881 instant stamp —
    /// that stamp is a different record with its own self-echo
    /// clear and one-second grace, so reading it would let a
    /// change to #881 red this suite for an unrelated reason
    /// (architect review, 2026-08-29). No echo ever arrives in a
    /// test, which is precisely the stale-geometry window a glide
    /// frame lands in on a real machine.
    func commandedWidth(_ id: UInt32 = 1) -> CGFloat? {
        core.tiler.animation.commandedFrame(
            window: WindowID(id),
            includingHeldGlide: true
        )?.width
    }

    var ratio: Double {
        let space = core.state.workspaces.space(
            of: WindowID(1)
        )!
        return core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[space]!
        ).splitRatioH
    }

    var hits: LuaValue? { core.lua?.global("hits") }
    var heldID: UInt32? { core.keys.holdGlide.heldID }

    /// Fires the one pre-glide wait, starting the glide.
    func beginGlide() throws {
        let tick = ticks.popLast()
        try #require(tick).work()
    }

    /// One display frame of glide.
    func frame(_ dt: TimeInterval = 1.0 / 60) throws {
        // Bound before calling: `#require(x)(y)` crashes
        // the 6.x type checker (ConstraintSystem assertion).
        let tick = try #require(frameTick)
        tick(dt)
    }
}
