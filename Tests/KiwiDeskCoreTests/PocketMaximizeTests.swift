import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An out pocket window maximizes as any float (#3385): a second
/// press returns it, putting it back in the pocket ends the Maximize
/// and files the frame it returns to, and a take-out lands it plain
/// there. Reads the host's first screen, which the pocket files a
/// frame under.
@Suite("Pocket window maximize (#3385)", .serialized)
@MainActor
struct PocketMaximizeTests {
    private let one = WindowID(1)
    private let slot = CGRect(x: 0, y: 0, width: 800, height: 1000)

    /// Space 1 in bsp with w1 (focused) and w2 tiled, on the host's
    /// first screen; every frame sent lands, as a real app's does.
    private func core() throws -> (KiwiCore, CGRect) {
        weak var weakCore: KiwiCore?
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-pocket-max-\(UUID().uuidString)")
        )
        weakCore = core
        let screen = try #require(ScreenList.all.first)
        let id = try #require(screen.kiwiDisplayID)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        let area = GeometryUtils.axVisibleFrame(of: screen)
        core.tiler.visibleBounds = { _ in area }
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

    /// The window Space 1's Maximize names.
    private func maximized(_ core: KiwiCore) -> WindowID? {
        core.state.workspaces[SpaceID("1")].flatMap {
            core.state.maximizedWindow(of: $0)
        }
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

    @Test("an out pocket window maximizes, and a second press returns it")
    func maximizesAndReturns() throws {
        let (core, area) = try core()
        let own = outWindow(core, area)
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(maximized(core) == one)
        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(maximized(core) == nil)
        #expect(core.state.windows[one]?.frame.size == own.size)
    }

    @Test("a put-back ends the Maximize and files its return frame")
    func putBackFilesTheReturn() throws {
        let (core, area) = try core()
        let own = outWindow(core, area)
        core.execute("toggle_maximized")
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        #expect(maximized(core) == nil)
        let filed = try #require(core.state.pocket.first?.frames.values.first)
        #expect(filed.size == own.size)
        // The take-out lands it plain, at that frame.
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(maximized(core) == nil)
        let back = try #require(
            core.tiler.stashOriginal(one) ?? core.state.windows[one]?.frame
        )
        #expect(back.size == own.size)
    }

    @Test("marking a maximized float keeps its Maximize")
    func markKeepsTheMaximize() throws {
        let (core, area) = try core()
        core.execute("toggle_floating")
        let own = CGRect(
            x: area.minX + 60,
            y: area.minY + 60,
            width: 420,
            height: 260
        )
        core.state.apply(.windowResized(one, own))
        core.execute("toggle_maximized")
        core.execute("toggle_pocket_window")
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(maximized(core) == one)
        core.execute("toggle_maximized")
        #expect(core.state.windows[one]?.frame.size == own.size)
    }
}
