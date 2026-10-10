import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A float's pending capture is delivered once the window stands
/// at its ORIGIN; the size is the app's to refuse (#2129). A
/// capture held for a refused size re-sent it on every retile —
/// the ring drew the ask — and the snapshot recorded the ask as
/// the window's frame. A set that never landed is sent again.
@Suite("A refused size retires the capture (#2129)", .serialized)
@MainActor
struct StashRefusedSizeTests {
    private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    private let window = WindowID(2)

    /// Space 1 scrolling with w1 and w2 (w2 focused at a
    /// scrolled-out slot), Space 2 floating; w2 followed into it,
    /// so its centred placement was delivered instantly.
    private func followed() throws -> (KiwiCore, CGRect) {
        let core = makeTestCore()
        let screen = self.screen
        core.tiler.visibleBounds = { _ in screen }
        core.tiler.allScreenBounds = { [screen] }
        // Pinned (#660): the move's placement is the centred one.
        core.tiler.settings.floatPlacement = .center
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.execute(
            "set_mode",
            args: [.string("2"), .string("floating")]
        )
        let slot = CGRect(x: -300, y: 60, width: 600, height: 900)
        for index in 1...2 {
            let id = WindowID(UInt32(index))
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 1, appName: "A")
                )
            )
            core.state.apply(.windowResized(id, slot))
        }
        core.state.apply(.windowFocused(window))
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { _, _, _ in }
        #expect(
            core.execute(
                "move_to_space_and_follow",
                args: [.string("2")]
            ).isSuccess
        )
        let asked = try #require(core.tiler.recentInstantTarget(window))
        return (core, asked)
    }

    @Test("the app's wider answer retires the capture and is recorded")
    func refusedSizeRetires() throws {
        let (core, asked) = try followed()
        // The app keeps a wider minimum, at the asked origin.
        var real = asked
        real.size.width += 45
        core.handle(.windowResized(window, real))
        core.retile(pass: .apply)
        #expect(core.tiler.stashOriginal(window) == nil)
        core.retile(pass: .apply)
        #expect(core.tiler.recentInstantTarget(window) == nil)
        let record = core.sessionSnapshot().windows.first {
            $0.windowID == window
        }
        #expect(record?.frame == real)
    }

    /// The control: an answer away from the asked origin is a set
    /// that did not land, and the capture keeps re-sending it.
    @Test("a set that never landed is sent again")
    func lostSetRetries() throws {
        let (core, asked) = try followed()
        let elsewhere = asked.offsetBy(dx: 0, dy: 40)
        core.handle(.windowMoved(window, elsewhere))
        // An echo inside the grace is ours: the capture stands.
        core.retile(pass: .apply)
        #expect(core.tiler.stashOriginal(window) == asked)
        #expect(core.tiler.recentInstantTarget(window) == asked)
    }

    /// A capture never sent is not delivered by an origin match:
    /// a seed at the window's own origin with another size is
    /// sent, the size included.
    @Test("an unsent capture at the window's origin is sent")
    func unsentCaptureIsSent() throws {
        let (core, asked) = try followed()
        core.handle(.windowResized(window, asked))
        core.retile(pass: .apply)
        #expect(core.tiler.stashOriginal(window) == nil)
        var smaller = asked
        smaller.size.height -= 100
        core.tiler.seedStash(window, frame: smaller)
        core.retile(pass: .apply)
        #expect(core.tiler.recentInstantTarget(window) == smaller)
        #expect(core.tiler.stashOriginal(window) == smaller)
    }
}
