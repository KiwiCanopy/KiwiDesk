import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The shared PRODUCTION fixture for hold-to-glide
/// (#1056/#1082): a real `KiwiCore`, a real Lua binding body, a
/// real release-reporting registrar — only the pre-glide wait and
/// the frame clock are captured, so a frame reaches the real
/// `resize`. Its own file because two suites drive it —
/// `HoldRepeatWiringTests` and `HoldGlideRefusalWiringTests` —
/// split at §2.1's ceiling rather than after crossing it.
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
        core.keys.holdRepeat.initialDelay = { 0.5 }
        core.keys.holdRepeat.schedule = {
            [weak self] delay, work in
            self?.ticks.append((delay, work))
            return {}
        }
        // The live seam is a `CADisplayLink` on a real
        // screen; capture the callback instead and drive
        // frames by hand. `applyGlideStep` is deliberately
        // NOT stubbed — the whole point of this suite is
        // that a frame reaches the real `resize`.
        core.keys.holdRepeat.startFrames = {
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

    var ratio: Double {
        let space = core.state.workspaces.space(
            of: WindowID(1)
        )!
        return core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[space]!
        ).splitRatioH
    }

    var hits: LuaValue? { core.lua?.global("hits") }
    var heldID: UInt32? { core.keys.holdRepeat.heldID }

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
