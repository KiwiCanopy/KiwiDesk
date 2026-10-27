import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The brief pocket (#2680): pocketing and taking out play it under
/// `on_state_change` and never under Reduce Motion; the window parks
/// at once, and a take-out's one write waits for the plate to land.
/// Its placement settings, `pocket.edge` and `pocket.position`.
@Suite("Brief pocket", .serialized)
@MainActor
struct BriefPocketTests {
    private let one = WindowID(1)

    private func makeCore(plays: Bool = true) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-brief-pocket-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.briefPocket.reduceMotion = { !plays }
        core.briefPocket.present = { _ in }
        core.briefPocket.makeFrames = { _, _ in nil }
        // An element and an inert writer, so a held write stays
        // staged rather than dropped for want of one.
        let element = AXUIElementCreateApplication(1)
        core.tiler.applier.elementProvider = { _ in element }
        core.tiler.applier.writer = FrameWriter(
            setFrame: { _, _ in },
            setPosition: { _, _ in },
            writeEUI: { _, _ in }
        )
        for raw: UInt32 in [1, 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_001,
                        appName: "App\(raw)",
                        frame: CGRect(
                            x: 100,
                            y: 100,
                            width: 600,
                            height: 400
                        )
                    )
                )
            )
        }
        core.focusWindow(one, warp: false)
        return core
    }

    /// Counts animated applies of the window from here on.
    private func countApplies(_ core: KiwiCore) -> () -> Int {
        core.tiler.animation.isEnabled = false
        var applies = 0
        core.tiler.animation.apply = { id, _, _ in
            if id == WindowID(1) { applies += 1 }
        }
        return { applies }
    }

    @Test("pocketing plays the pocket and parks the window at once")
    func pocketingPlays() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        let applies = countApplies(core)
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketedWindow == one)
        #expect(core.briefPocket.isPlaying)
        #expect(applies() == 0)
    }

    /// The play takes the stored placement and the gated looks.
    @Test("the play wears the stored placement and the gated looks")
    func requestWiring() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        // Reduce transparency on, glass stored on: the gated looks
        // differ from the stored ones.
        let gate = LiquidGlassGate.override
        LiquidGlassGate.override = { true }
        defer { LiquidGlassGate.override = gate }
        core.tiler.settings.kiwishelf.liquidGlass = true
        core.tiler.settings.shortcutPanelLiquidGlass = true
        core.tiler.settings.pocketStyle.edge = .right
        core.tiler.settings.pocketStyle.position = 30
        #expect(core.execute("pocket").isSuccess)
        let request = try #require(core.briefPocket.playing)
        let region = core.tiler.visibleBounds(request.screen)
        #expect(
            request.pocket
                == BriefPocketPlan.pocketFrame(
                    in: region,
                    edge: .right,
                    position: 30
                )
        )
        let settings = core.tiler.settings
        #expect(request.shelf != settings.kiwishelf)
        #expect(request.shelf == LiquidGlassGate.rendered(settings.kiwishelf))
        #expect(!request.plateGlass)
    }

    @Test("taking out plays the pocket and holds the one write")
    func takeOutPlaysAndHolds() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        #expect(core.execute("pocket").isSuccess)
        core.briefPocket.end()
        let applies = countApplies(core)
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketedWindow == nil)
        #expect(core.briefPocket.isPlaying)
        #expect(core.tiler.applier.held.isHeld(one))
        // The restore's one write is staged, not sent ahead of it.
        #expect(core.tiler.applier.held.isStaged(one))
        // Its ring waits with it, and lets go at the landing.
        #expect(core.borders.stateChange?.window == one)
        core.borders.stateChangeSettled(one)
        core.borders.noteStateChangeReport(
            one,
            frame: core.tiler.commandedFrame(of: one) ?? .zero
        )
        #expect(core.borders.stateChange == nil)
        #expect(applies() == 0)
    }

    @Test("off under the toggle or Reduce Motion: nothing plays or holds")
    func gated() {
        guard NSScreen.main != nil else { return }
        for (toggle, plays) in [(false, true), (true, false)] {
            let core = makeCore(plays: plays)
            core.tiler.settings.animations.onStateChange = toggle
            #expect(core.execute("pocket").isSuccess)
            #expect(!core.briefPocket.isPlaying)
            #expect(core.execute("pocket").isSuccess)
            #expect(!core.briefPocket.isPlaying)
            #expect(!core.tiler.applier.held.isHeld(one))
        }
    }

    @Test("edge and position decode absent as bottom, 82")
    func storedShape() throws {
        let absent = try JSONDecoder().decode(
            PocketStyle.self,
            from: Data("{}".utf8)
        )
        #expect(absent.edge == .bottom)
        #expect(absent.position == 82)
        let set = try JSONDecoder().decode(
            PocketStyle.self,
            from: Data(#"{"edge":"left","position":140}"#.utf8)
        )
        #expect(set.edge == .left)
        #expect(set.position == 100)
        let encoded =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(PocketStyle())
            ) as? [String: Any]
        #expect(encoded?["edge"] as? String == "bottom")
        #expect(encoded?["position"] as? Double == 82)
    }

    @Test("the Lua verbs set them and refuse a bad value")
    func verbs() {
        let core = makeCore()
        #expect(
            core.execute("pocket.set_edge", args: [.string("top")])
                .isSuccess
        )
        #expect(core.tiler.settings.pocketStyle.edge == .top)
        #expect(
            !core.execute("pocket.set_edge", args: [.string("middle")])
                .isSuccess
        )
        #expect(
            core.execute("pocket.set_position", args: [.number(30)])
                .isSuccess
        )
        #expect(core.tiler.settings.pocketStyle.position == 30)
        #expect(
            core.execute("pocket.set_position", args: [.number(-5)])
                .isSuccess
        )
        #expect(core.tiler.settings.pocketStyle.position == 0)
        #expect(
            !core.execute("pocket.set_position", args: [.string("x")])
                .isSuccess
        )
    }
}
