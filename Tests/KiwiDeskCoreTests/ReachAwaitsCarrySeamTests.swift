import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)

private final class FakePlistArrayResult: NSObject {
    @objc let propertyListArray: [[String: Any]]
    init(propertyListArray: [[String: Any]]) {
        self.propertyListArray = propertyListArray
    }
}

/// The availability probe, answering — the bridge is present.
private final class FakeCopyManagedDisplaySpaces: NSObject {
    @objc override init() {}
    @objc func performWithWMBridgeDelegate() -> AnyObject? {
        FakePlistArrayResult(propertyListArray: [["Spaces": []]])
    }
}

private let bridgeClasses: [String: AnyClass] = [
    "CopyManagedDisplaySpacesOperation":
        FakeCopyManagedDisplaySpaces.self
]

// MARK: - Suite

/// The reach-departure arm's reading is WIRED (#1215): the
/// bootstrap hands `EventLoop.reachAwaitsCarry` the core's
/// `stickyReachAwaitsCarry`, which answers "the carry owes this
/// window a move" from the carry's own enabled set and the gone
/// classifier's compositor door (`gonePresence`, #1146): hosted
/// on the user Space the switch handler last filed for its
/// display while that display now shows another — a switch the
/// handler has not run for. A default left in place keeps every
/// gesture departure a close with every other suite green, which
/// is why the wiring is pinned here and not the predicate alone.
/// Process-global topology and resolver overrides, so serialized.
/// The bridge fake is `StickyReachCarryVerdictTests`' per-file
/// copy (tests.md).
@MainActor
@Suite("Reach-awaits-carry seam (#1215)", .serialized)
struct ReachAwaitsCarrySeamTests {
    private let window = WindowID(748_805)

    /// Mid-switch: the display now shows Desktop 2 (space 2)
    /// while the handler last filed Desktop 1 (space 1) — the
    /// beat in which a gesture's destroys land; a fullscreen
    /// Space beside them; the window sticky and tiled.
    private func makeCore(bridge: Bool = true) -> KiwiCore {
        NativeSpaces.spacesOverride = [
            authoritySpace(1, display: "UUID-A"),
            authoritySpace(2, display: "UUID-A", current: true),
            authoritySpace(1716, display: "UUID-A", isUser: false),
        ]
        WMBridge.classResolverOverride = { name in
            bridge ? bridgeClasses[name] : nil
        }
        let core = makeAuthorityCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: window, pid: 1, appName: "App")
            )
        )
        core.state.setSticky(window, .global)
        core.desktopMemory.lastDisplaySpaces = ["UUID-A": 1]
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        NativeSpaces.spacesOverride = nil
    }

    @Test("a sticky left on the Space of an unfiled switch opens the arm")
    func pendingSwitchOpensTheArm() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.stickyReachCarried().contains(window))
        core.desktopMemory.readWindowSpace = { _ in .hosted(1) }
        #expect(core.eventLoop.reachAwaitsCarry(window))
    }

    @Test("once the handler filed the switch the arm is closed")
    func filedSwitchClosesTheArm() {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(1) }
        // The handler ran: what it filed is what the display shows.
        core.desktopMemory.lastDisplaySpaces = ["UUID-A": 2]
        #expect(!core.eventLoop.reachAwaitsCarry(window))
        // A display never filed opens nothing either.
        core.desktopMemory.lastDisplaySpaces = [:]
        #expect(!core.eventLoop.reachAwaitsCarry(window))
    }

    @Test("an unshown host with no switch pending opens nothing")
    func unshownHostWithoutASwitchDoesNotOpenTheArm() {
        let core = makeCore()
        defer { teardown() }
        // A move verb's hand-off or a Mission Control drag: the
        // window sits on an unshown Desktop while the display
        // still shows what the handler last filed (review,
        // 2026-09-21) — "unshown" alone would refuse the verb's
        // own reap and re-tile the departed window.
        NativeSpaces.spacesOverride = [
            authoritySpace(1, display: "UUID-A", current: true),
            authoritySpace(2, display: "UUID-A"),
        ]
        core.desktopMemory.readWindowSpace = { _ in .hosted(2) }
        #expect(!core.eventLoop.reachAwaitsCarry(window))
    }

    @Test("a shown-Desktop host does not — a closed one lingers there")
    func shownDesktopHostDoesNotOpenTheArm() {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(2) }
        #expect(!core.eventLoop.reachAwaitsCarry(window))
    }

    @Test("a fullscreen Space host is the fullscreen arm's, never this one's")
    func fullscreenSpaceHostDoesNotOpenTheArm() {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(1716) }
        #expect(!core.eventLoop.reachAwaitsCarry(window))
        #expect(core.eventLoop.fullscreenSpaceHosts(window))
    }

    @Test("gone, unavailable and an unlisted host never refuse")
    func unreadableHostsNeverRefuse() {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .gone }
        #expect(!core.eventLoop.reachAwaitsCarry(window))
        core.desktopMemory.readWindowSpace = { _ in .unavailable }
        #expect(!core.eventLoop.reachAwaitsCarry(window))
        // A Space the topology does not list names no display to
        // read a pending switch off.
        core.desktopMemory.readWindowSpace = { _ in .hosted(9_999) }
        #expect(!core.eventLoop.reachAwaitsCarry(window))
    }

    @Test("a window the carry does not follow never opens the arm")
    func uncarriedWindowDoesNotOpenTheArm() {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(1) }
        // The pin against the toggle.
        core.state.stickyReachOverrides[window] = false
        #expect(!core.eventLoop.reachAwaitsCarry(window))
        core.state.stickyReachOverrides[window] = nil
        // No sticky scope at all.
        core.state.setSticky(window, .none)
        #expect(!core.eventLoop.reachAwaitsCarry(window))
    }

    @Test("without the bridge nothing awaits a carry")
    func absentBridgeOpensNoArm() {
        let core = makeCore(bridge: false)
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(1) }
        #expect(core.stickyReachCarried().isEmpty)
        #expect(!core.eventLoop.reachAwaitsCarry(window))
    }
}
