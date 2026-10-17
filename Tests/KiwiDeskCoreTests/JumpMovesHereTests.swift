import Foundation
import Testing

@testable import KiwiDeskCore

private final class FakePlistArrayResult: NSObject {
    @objc let propertyListArray: [[String: Any]]
    init(propertyListArray: [[String: Any]]) {
        self.propertyListArray = propertyListArray
    }
}

private final class FakeCopyManagedDisplaySpaces: NSObject {
    @objc override init() {}
    @objc func performWithWMBridgeDelegate() -> AnyObject? {
        FakePlistArrayResult(propertyListArray: [["Spaces": []]])
    }
}

/// Whether a Jump to window row would move here (#1875): the fact
/// the panel draws ⇧'s way here by, read from the gates
/// `moveHere(_:)` applies rather than by the GUI. Topology: the
/// #888 fixture.
@Suite("Jump to window: moves here (#1875)", .serialized)
@MainActor
struct JumpMovesHereTests {
    private func makeCore(bridge: Bool = false) -> KiwiCore {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        pinTwoDisplays()
        WMBridge.classResolverOverride = { name in
            bridge && name == "CopyManagedDisplaySpacesOperation"
                ? FakeCopyManagedDisplaySpaces.self : nil
        }
        let core = makeTestCore()
        for space in ["1", "2"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.activate("1")
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    private func track(
        _ core: KiwiCore,
        _ id: UInt32,
        in space: String,
        configure: (inout ManagedWindow) -> Void = { _ in }
    ) {
        var window = ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "Notes",
            appBundleID: "app.test.notes"
        )
        configure(&window)
        core.state.apply(.windowCreated(window))
        core.state.workspaces.add(WindowID(id), to: SpaceID(space))
    }

    private func movesHere(_ core: KiwiCore, _ id: UInt32) -> Bool? {
        core.jumpEntries().first {
            $0.target == .window(WindowID(id))
        }?.movesHere
    }

    @Test("a tracked window elsewhere moves; one already here does not")
    func trackedWindows() {
        let core = makeCore()
        defer { teardown() }
        track(core, 1, in: "1")
        track(core, 2, in: "2")
        track(core, 3, in: "2") { $0.isFullscreen = true }
        track(core, 4, in: "2") { $0.stickyScope = .global }
        #expect(movesHere(core, 1) == false)
        #expect(movesHere(core, 2) == true)
        #expect(movesHere(core, 3) == false)
        // A ∞ window is drawn here already: Move here only focuses.
        #expect(movesHere(core, 4) == false)
    }

    @Test("a minimized window moves here")
    func minimizedWindow() {
        let core = makeCore()
        defer { teardown() }
        track(core, 5, in: "1")
        var effects = AppliedEffects()
        core.state.applyWindowDestroyed(
            WindowID(5),
            wasMinimized: true,
            effects: &effects
        )
        #expect(movesHere(core, 5) == true)
    }

    @Test("an away window moves here only with the Desktop bridge")
    func awayWindow() {
        for bridge in [false, true] {
            let core = makeCore(bridge: bridge)
            defer { teardown() }
            core.state.awayWindows[WindowID(7)] = AwayWindow(
                id: WindowID(7),
                pid: 100,
                appName: "Notes",
                appBundleID: "app.test.notes",
                nativeSpace: 11
            )
            core.state.rememberedSpaces[WindowID(7)] = .departed("2")
            #expect(core.canDriveDesktops == bridge)
            #expect(movesHere(core, 7) == bridge)
        }
    }

    /// The fact and the act agree: a row says it moves here
    /// exactly where `moveHere(_:)` files it into the current
    /// Space — the display-sticky arm included, whose block reads
    /// the screens.
    @Test("movesHere agrees with what Move here does")
    func agreesWithTheAct() {
        let scopes: [StickyScope] = [.none, .display, .global]
        for (offset, scope) in scopes.enumerated() {
            let core = makeCore()
            defer { teardown() }
            let id = UInt32(20 + offset)
            track(core, id, in: "2") { $0.stickyScope = scope }
            let claim = movesHere(core, id)
            core.moveHere(.window(WindowID(id)))
            let space = core.state.workspaces.space(of: WindowID(id))
            let moved = space == "1"
            #expect(claim == moved, Comment(rawValue: "\(scope)"))
        }
    }

    @Test("an away window with no bundle id cannot move here")
    func awayWithoutBundle() {
        let core = makeCore(bridge: true)
        defer { teardown() }
        core.state.awayWindows[WindowID(8)] = AwayWindow(
            id: WindowID(8),
            pid: 100,
            appName: "Notes",
            appBundleID: nil,
            nativeSpace: 11
        )
        core.state.rememberedSpaces[WindowID(8)] = .departed("2")
        #expect(movesHere(core, 8) == false)
    }
}
