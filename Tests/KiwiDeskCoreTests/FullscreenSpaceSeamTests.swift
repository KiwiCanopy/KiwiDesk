import Foundation
import Testing

@testable import KiwiDeskCore

/// The fullscreen arm's ENTER reading is WIRED (#1272): the
/// bootstrap hands `EventLoop.fullscreenSpaceHosts` the core's
/// `windowIsOnFullscreenSpace`, which answers from the gone
/// classifier's own compositor door (`desktopMemory.readWindowSpace`,
/// #1146) against the topology's `isUser`. A default left in
/// place keeps every ENTER beat a close with every other suite
/// green, which is why the wiring is pinned here and not the
/// predicate alone. Process-global topology override, so
/// serialized.
@MainActor
@Suite("Fullscreen-Space host seam (#1272)", .serialized)
struct FullscreenSpaceSeamTests {
    private let window = WindowID(748_804)

    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = [
            authoritySpace(1, display: "UUID-A", current: true),
            authoritySpace(1716, display: "UUID-A", isUser: false),
        ]
        return makeAuthorityCore()
    }

    private func teardown() {
        NativeSpaces.spacesOverride = nil
    }

    @Test("a window on a fullscreen Space opens the arm")
    func fullscreenSpaceHostOpensTheArm() {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(1716) }
        #expect(core.eventLoop.fullscreenSpaceHosts(window))
    }

    @Test("a window on a user Desktop does not — a closed one lingers there")
    func desktopHostDoesNotOpenTheArm() {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(1) }
        #expect(!core.eventLoop.fullscreenSpaceHosts(window))
    }

    @Test("gone, unavailable and an unlisted Space all read closed")
    func unreadableHostsNeverRefuse() {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .gone }
        #expect(!core.eventLoop.fullscreenSpaceHosts(window))
        core.desktopMemory.readWindowSpace = { _ in .unavailable }
        #expect(!core.eventLoop.fullscreenSpaceHosts(window))
        // A Space the topology does not list reads as a user one.
        core.desktopMemory.readWindowSpace = { _ in .hosted(9_999) }
        #expect(!core.eventLoop.fullscreenSpaceHosts(window))
    }
}
