import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A window that went into the pocket maximized comes out maximized
/// (#3408): on the active Space, in the shape it had, its return the
/// frame it came out at, so a second press puts it there; plain where
/// that Space already holds a Maximize. The slot keeps the shape
/// alone, set from the Space's own Maximize, and an older snapshot
/// without it still reads.
@Suite("Pocket take-out re-maximizes (#3408)", .serialized)
@MainActor
struct PocketTakeOutMaximizeTests {
    private let one = WindowID(1)
    private let two = WindowID(2)
    private let slot = CGRect(x: 0, y: 0, width: 800, height: 1000)

    /// Space 1 in bsp with w1 (focused) and w2 tiled, on the host's
    /// first screen; every frame sent lands, as a real app's does.
    private func core() throws -> (KiwiCore, CGRect) {
        weak var weakCore: KiwiCore?
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-pocket-out-\(UUID().uuidString)")
        )
        weakCore = core
        let screen = try #require(ScreenList.all.first)
        let id = try #require(screen.kiwiDisplayID)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        let area = GeometryUtils.axVisibleFrame(of: screen)
        core.tiler.visibleBounds = { _ in area }
        core.tiler.allScreenBounds = { [area] }
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        core.state.workspaces.assign(SpaceID("1"), to: id)
        for raw: UInt32 in [2, 1] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_000 + pid_t(raw),
                        appName: "App\(raw)",
                        title: "Window \(raw)",
                        frame: slot
                    )
                )
            )
        }
        core.state.apply(.windowFocused(one))
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            weakCore?.state.apply(.windowResized(id, frame))
        }
        return (core, area)
    }

    private func maximize(_ core: KiwiCore) -> Maximize? {
        core.state.workspaces[SpaceID("1")]?.maximized
    }

    /// Marks w1 out and gives it a float frame of its own.
    private func outWindow(_ core: KiwiCore, _ area: CGRect) -> CGRect {
        core.execute("toggle_pocket_window")
        let own = CGRect(
            x: area.minX + 40,
            y: area.minY + 40,
            width: 500,
            height: 300
        )
        core.state.apply(.windowResized(one, own))
        return own
    }

    @Test("a take-out maximizes again, and a second press returns it")
    func takeOutRemaximizes() throws {
        let (core, area) = try core()
        let own = outWindow(core, area)
        core.execute("toggle_maximized")
        core.execute("pocket")
        #expect(maximize(core) == nil)
        core.execute("pocket")
        #expect(maximize(core)?.window == one)
        #expect(core.state.pocketSlot(of: one)?.returnMaximized == nil)
        // Seeded with the filed frame, never the park it left.
        #expect(core.state.maximizedFloatReturn[one]?.frame == own)
        core.execute("toggle_maximized")
        #expect(maximize(core) == nil)
        let back = try #require(core.state.windows[one]?.frame)
        #expect(back.size == own.size)
        #expect(area.contains(back))
    }

    @Test("it comes back in the shape it went in with")
    func shapeComesBack() throws {
        let (core, area) = try core()
        _ = outWindow(core, area)
        core.execute("toggle_maximized", args: [.string("height")])
        let shape = try #require(maximize(core)?.shape)
        core.execute("pocket")
        #expect(core.state.pocketSlot(of: one)?.returnMaximized == shape)
        core.execute("pocket")
        #expect(maximize(core)?.shape == shape)
    }

    @Test("a Space that already holds a Maximize takes it out plain")
    func occupiedSpaceIsPlain() throws {
        let (core, area) = try core()
        let own = outWindow(core, area)
        core.execute("toggle_maximized")
        core.execute("pocket")
        core.state.apply(.windowFocused(two))
        core.execute("toggle_maximized")
        #expect(maximize(core)?.window == two)
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(maximize(core)?.window == two)
        #expect(core.state.maximizedFloatReturn[one] == nil)
        let back = try #require(
            core.tiler.stashOriginal(one) ?? core.state.windows[one]?.frame
        )
        #expect(back.size == own.size)
    }

    @Test("a take-out a press would refuse comes out plain, spent")
    func refusedIsPlain() throws {
        let (core, area) = try core()
        _ = outWindow(core, area)
        core.execute("toggle_maximized")
        core.execute("pocket")
        // A transient overlay takes no Maximize from a press.
        var window = try #require(core.state.windows[one])
        window.isTransientOverlay = true
        core.state.windows.upsert(window)
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(maximize(core) == nil)
        #expect(core.state.maximizedFloatReturn[one] == nil)
        #expect(core.state.pocketSlot(of: one)?.returnMaximized == nil)
    }

    @Test("a plain put-back comes out plain, the flag spent")
    func plainStaysPlain() throws {
        let (core, area) = try core()
        _ = outWindow(core, area)
        core.execute("toggle_maximized")
        core.execute("pocket")
        core.execute("pocket")
        // The take-out spent it.
        #expect(core.state.pocketSlot(of: one)?.returnMaximized == nil)
        core.execute("toggle_maximized")
        #expect(maximize(core) == nil)
        core.execute("pocket")
        #expect(core.state.pocketSlot(of: one)?.returnMaximized == nil)
        core.execute("pocket")
        #expect(maximize(core) == nil)
    }

    @Test("the flag reads the Maximize of the Space it is drawn on")
    func renderSpaceMaximizeIsRead() throws {
        let (core, area) = try core()
        _ = outWindow(core, area)
        // Out, it renders on every Space; its home stays Space 1.
        core.execute("focus_space", args: [.string("2")])
        core.state.apply(.windowFocused(one))
        core.execute("toggle_maximized")
        let other = core.state.workspaces[SpaceID("2")]?.maximized
        #expect(other?.window == one)
        core.execute("pocket")
        #expect(core.state.pocketSlot(of: one)?.returnMaximized != nil)
    }

    @Test("a return record with no Maximize sets no flag")
    func staleRecordIsNoFlag() throws {
        let (core, area) = try core()
        let own = outWindow(core, area)
        core.state.maximizedFloatReturn[one] = .init(pid: 900_001, frame: own)
        core.execute("pocket")
        #expect(core.state.pocketSlot(of: one)?.returnMaximized == nil)
    }

    @Test("the slot's shape crosses a restart")
    func snapshotCrossing() throws {
        let (core, area) = try core()
        _ = outWindow(core, area)
        core.execute("toggle_maximized")
        core.execute("pocket")
        let shape = try #require(
            core.state.pocketSlot(of: one)?.returnMaximized
        )
        let snapshot = core.state.inPlaceSnapshot(
            monocleShown: [:],
            ratios: { _ in .init(entries: [:], drawn: SessionRatios()) }
        )
        let data = try JSONEncoder().encode(snapshot)
        let read = try JSONDecoder().decode(StateSnapshot.self, from: data)
        #expect(read.pocket.first?.returnMaximized == shape)
        // An older snapshot's slot is `PocketSurfaceTests` ▸
        // `inPlaceCarries`'.
    }
}
