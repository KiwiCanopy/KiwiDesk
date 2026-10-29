import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A take-out's raise waits for the brief pocket's play (#2703), and
/// macOS re-reports focus on the window it left meanwhile: that
/// re-report must not cancel the raise, while a move to any other
/// window still does (#2678).
@Suite("Pocket landing", .serialized)
@MainActor
struct PocketLandingTests {
    private let one = WindowID(1)
    private let two = WindowID(2)
    private let three = WindowID(3)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-landing-\(UUID().uuidString)")
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.briefPocket.reduceMotion = { false }
        core.briefPocket.present = { _ in }
        core.briefPocket.makeFrames = { _, _ in nil }
        core.deferred.sleep = { _ in }
        for raw: UInt32 in [1, 2, 3] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_001,
                        appName: "App\(raw)",
                        frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                    )
                )
            )
        }
        let element = AXUIElementCreateSystemWide()
        core.eventLoop.elements[900_001] = [
            one: element, two: element, three: element,
        ]
        core.focusWindow(one, warp: false)
        return core
    }

    private func raised(_ core: KiwiCore, _ id: WindowID) -> Bool {
        core.selfRaiseStamps[id] != nil
    }

    /// Pockets `one`, lands that play, takes `one` out again and
    /// answers the window it came out over.
    private func takeOut(_ core: KiwiCore) async -> WindowID? {
        #expect(core.execute("pocket").isSuccess)
        await core.deferred.task(for: .pocketFocus)?.value
        core.briefPocket.end()
        let left = core.state.workspaces.lastFocused
        // Only the take-out's own raise counts from here.
        core.selfRaiseStamps[one] = nil
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(!raised(core, one))
        return left
    }

    private func refocus(_ core: KiwiCore, _ id: WindowID) {
        guard let space = core.state.workspaces.space(of: id) else {
            return
        }
        core.state.workspaces.focus(id, in: space)
    }

    @Test("the left window's re-report leaves the take-out's raise")
    func reReportKeepsTheRaise() async throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        let left = try #require(await takeOut(core))
        refocus(core, left)
        await core.deferred.task(for: .pocketFocus)?.value
        #expect(raised(core, one))
    }

    @Test("a move to another window still cancels it")
    func otherMoveCancels() async throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        let left = try #require(await takeOut(core))
        let other = try #require([two, three].first { $0 != left })
        refocus(core, other)
        await core.deferred.task(for: .pocketFocus)?.value
        #expect(!raised(core, one))
    }
}
