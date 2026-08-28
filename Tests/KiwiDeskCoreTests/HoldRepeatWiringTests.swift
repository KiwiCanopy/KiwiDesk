import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A registrar fake that can report releases — the channel the
/// hold-to-repeat engine arms on (#1056). The press-only fakes
/// across the test trees deliberately do NOT conform, which is
/// the `HotkeyReleaseReporting` split working as designed.
@MainActor
private final class ReleaseRegistrar: HotkeyRegistrar,
    HotkeyReleaseReporting
{
    var onRelease: @MainActor (UInt32) -> Void = { _ in }
    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var keyCodes: [UInt32: UInt32] = [:]
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        let id = nextID
        nextID += 1
        handlers[id] = handler
        keyCodes[id] = keyCode
        return id
    }

    func unregister(id: UInt32) {
        handlers[id] = nil
        keyCodes[id] = nil
    }

    func press(keyCode: UInt32) {
        for (id, code) in keyCodes where code == keyCode {
            handlers[id]?()
        }
    }

    /// Mirrors `CarbonHotkeyCenter.dispatchRelease`: a release
    /// for an unregistered id is dropped.
    func release(keyCode: UInt32) {
        for (id, code) in keyCodes where code == keyCode {
            onRelease(id)
        }
    }
}

/// The production half of hold-to-repeat (#1056): a real chord
/// driving a real binding body through `KiwiCore.execute`'s
/// command tally, the refusal-cue sites, and the teardown
/// cancels. This is what reds if the tally call, a cue's
/// `noteResizeRefusal()` or the release wiring is deleted — the
/// machine ladder (`HoldRepeatTests`) cannot see any of those.
@MainActor
@Suite("Hold-to-repeat wiring (#1056)")
struct HoldRepeatWiringTests {
    @MainActor
    private final class Fixture {
        let core: KiwiCore
        let registrar: ReleaseRegistrar
        let combo: KeyCombo
        var ticks: [(delay: TimeInterval, work: () -> Void)] =
            []

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
            core.keys.holdRepeat.interval = { 0.1 }
            core.keys.holdRepeat.schedule = {
                [weak self] delay, work in
                self?.ticks.append((delay, work))
                return {}
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
    }

    @Test("A held chord repeats a lone resize until release")
    func chordArmsTicksAndReleases() throws {
        let f = try Fixture(
            body: #"KiwiDesk.resize("x", 50)"#
        )
        f.seedBspPair()
        let idle = f.ratio

        f.registrar.press(keyCode: f.combo.keyCode)
        #expect(f.hits == .number(1))
        let afterPress = f.ratio
        #expect(afterPress > idle)
        #expect(f.heldID != nil)
        #expect(f.ticks.map(\.delay) == [0.5])

        // The tick re-runs the whole binding body through the
        // production re-fire, and the run goes on at the
        // repeat interval. The `#require`s are load-bearing
        // (guard-prover, #1056): an arming regression must
        // fail HERE, not trap the runner on an empty array.
        let tick = f.ticks.popLast()
        try #require(tick).work()
        #expect(f.hits == .number(2))
        #expect(f.ratio > afterPress)
        #expect(f.ticks.map(\.delay) == [0.1])

        // The physical release ends it; the pending tick's late
        // fire is inert.
        f.registrar.release(keyCode: f.combo.keyCode)
        #expect(f.heldID == nil)
        let lateTick = f.ticks.popLast()
        try #require(lateTick).work()
        #expect(f.hits == .number(2))
    }

    @Test("A body that is not exactly one resize never arms")
    func ineligibleBodiesNeverArm() throws {
        // Two commands: repeating the rest was never asked for.
        let two = try Fixture(
            body: """
                KiwiDesk.resize("x", 50)
                KiwiDesk.focus("left")
                """
        )
        two.seedBspPair()
        two.registrar.press(keyCode: two.combo.keyCode)
        #expect(two.hits == .number(1))
        #expect(two.heldID == nil)
        #expect(two.ticks.isEmpty)

        // One command, but not resize.
        let focus = try Fixture(
            body: #"KiwiDesk.focus("left")"#
        )
        focus.seedBspPair()
        focus.registrar.press(keyCode: focus.combo.keyCode)
        #expect(focus.heldID == nil)
        #expect(focus.ticks.isEmpty)
    }

    @Test("A refusal reached mid-run ends the run")
    func midRunRefusalEndsTheRun() throws {
        // A held bsp shrink walks the ratio toward the floor;
        // the tick that gets clamped fires the real #933 cue
        // inside its own fire, which must be the run's last —
        // one pill per hold. Which cue SITES feed the engine is
        // `HoldRepeatSeamTests`' derived scan, not a list here.
        let f = try Fixture(
            body: #"KiwiDesk.resize("x", -200)"#
        )
        f.core.execute(
            "set_min_window_size",
            args: [.number(300)]
        )
        f.seedBspPair()

        f.registrar.press(keyCode: f.combo.keyCode)
        #expect(f.hits == .number(1))
        #expect(f.heldID != nil)

        // Ticks shrink further until the clamp truncates; the
        // run must end on that tick, with no new tick pending.
        var ticks = 0
        while f.heldID != nil {
            let tick = f.ticks.popLast()
            try #require(tick).work()
            ticks += 1
            try #require(ticks < 10)
        }
        #expect(ticks >= 1)
        #expect(f.ticks.isEmpty)
    }

    @Test("A press refused at the wall arms nothing")
    func refusedPressNeverArms() throws {
        // A floating window already at the minimum: the shrink
        // truncates, the #933 cue fires inside the press-fire,
        // and holding must not tick a pill per repeat.
        let f = try Fixture(
            body: #"KiwiDesk.resize("x", -50)"#
        )
        f.core.execute(
            "set_min_window_size",
            args: [.number(300)]
        )
        f.core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "FloatApp",
                    frame: CGRect(
                        x: 100,
                        y: 100,
                        width: 300,
                        height: 300
                    ),
                    isFloating: true
                )
            )
        )
        let space = f.core.state.workspaces.space(
            of: WindowID(1)
        )!
        f.core.state.workspaces.focus(WindowID(1), in: space)

        f.registrar.press(keyCode: f.combo.keyCode)
        #expect(f.hits == .number(1))
        #expect(f.heldID == nil)
        #expect(f.ticks.isEmpty)
    }

    @Test("A body that rebuilds the bindings ends its own run")
    func rebindingBodyEndsTheRun() throws {
        // `bind` inside the body re-registers everything,
        // minting fresh ids for the same ref+combo — and the
        // physical release will arrive (if at all) for an id
        // that no longer exists. The arm must stay keyed to the
        // id the press actually produced (`RegistrationBox`),
        // so the first tick finds its registration gone and the
        // run ends; re-deriving the id after the fire instead
        // adopts the fresh id and repeats on a registration the
        // press never touched (#1056 review).
        let f = try Fixture(
            body: """
                KiwiDesk.bind("ctrl+alt+k", function() end)
                KiwiDesk.resize("x", 50)
                """
        )
        f.seedBspPair()
        f.registrar.press(keyCode: f.combo.keyCode)
        guard f.heldID != nil else {
            // Arming from the stale-bindings press is itself
            // acceptable to refuse; the defect is repeating on
            // a foreign id, which the tick below would show.
            #expect(f.ticks.isEmpty)
            return
        }
        let tick = f.ticks.popLast()
        try #require(tick).work()
        #expect(f.heldID == nil)
        #expect(f.ticks.isEmpty)
    }

    @Test("Suspend and a layer switch cancel a live run")
    func teardownPathsCancel() throws {
        let f = try Fixture(
            body: #"KiwiDesk.resize("x", 50)"#
        )
        f.seedBspPair()

        f.registrar.press(keyCode: f.combo.keyCode)
        #expect(f.heldID != nil)
        f.core.keys.suspend()
        #expect(f.heldID == nil)
        f.core.keys.resume()
        f.ticks = []

        f.registrar.press(keyCode: f.combo.keyCode)
        #expect(f.heldID != nil)
        f.core.keys.switchLayer("r")
        #expect(f.heldID == nil)
    }
}
