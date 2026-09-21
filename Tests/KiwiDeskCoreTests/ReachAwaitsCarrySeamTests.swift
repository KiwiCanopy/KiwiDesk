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
/// on a user Desktop nobody shows. A default left in place keeps
/// every gesture departure a close with every other suite green,
/// which is why the wiring is pinned here and not the predicate
/// alone. Process-global topology and resolver overrides, so
/// serialized. The bridge fake is `StickyReachCarryVerdictTests`'
/// per-file copy (tests.md).
@MainActor
@Suite("Reach-awaits-carry seam (#1215)", .serialized)
struct ReachAwaitsCarrySeamTests {
    private let window = WindowID(748_805)

    /// Desktop 1 (space 1) shown, Desktop 2 (space 2) not, a
    /// fullscreen Space beside them; the window sticky and tiled.
    private func makeCore(bridge: Bool = true) -> KiwiCore {
        NativeSpaces.spacesOverride = [
            authoritySpace(1, display: "UUID-A", current: true),
            authoritySpace(2, display: "UUID-A"),
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
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        NativeSpaces.spacesOverride = nil
    }

    @Test("a reach-enabled sticky on an unshown Desktop opens the arm")
    func unshownDesktopHostOpensTheArm() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.stickyReachCarried().contains(window))
        core.desktopMemory.readWindowSpace = { _ in .hosted(2) }
        #expect(core.eventLoop.reachAwaitsCarry(window))
    }

    @Test("a shown-Desktop host does not — a closed one lingers there")
    func shownDesktopHostDoesNotOpenTheArm() {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(1) }
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

    @Test("gone and unavailable never refuse; an unlisted host does, bounded")
    func unreadableHostsNeverRefuse() {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .gone }
        #expect(!core.eventLoop.reachAwaitsCarry(window))
        core.desktopMemory.readWindowSpace = { _ in .unavailable }
        #expect(!core.eventLoop.reachAwaitsCarry(window))
        // A Space the topology does not list reads as unshown and
        // user (the classifier's own `vanished`): a refusal, which
        // the recheck budget bounds — never a wrong close.
        core.desktopMemory.readWindowSpace = { _ in .hosted(9_999) }
        #expect(core.eventLoop.reachAwaitsCarry(window))
    }

    @Test("a window the carry does not follow never opens the arm")
    func uncarriedWindowDoesNotOpenTheArm() {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(2) }
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
        core.desktopMemory.readWindowSpace = { _ in .hosted(2) }
        #expect(core.stickyReachCarried().isEmpty)
        #expect(!core.eventLoop.reachAwaitsCarry(window))
    }
}
