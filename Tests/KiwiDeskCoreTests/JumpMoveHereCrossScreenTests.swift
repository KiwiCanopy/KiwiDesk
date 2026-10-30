import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)

private enum Bridge {
    nonisolated(unsafe) static var moves: [([NSNumber], UInt64)] = []
}

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

private final class FakeMoveWindows: NSObject {
    private let windows: [NSNumber]
    private let space: UInt64

    @objc(initWithWindows:spaceID:)
    init(windows: [NSNumber], spaceID: UInt64) {
        self.windows = windows
        space = spaceID
    }

    @objc func performWithWMBridgeDelegate() {
        Bridge.moves.append((windows, space))
    }
}

private let bridgeClasses: [String: AnyClass] = [
    "CopyManagedDisplaySpacesOperation":
        FakeCopyManagedDisplaySpaces.self,
    "MoveWindowsToManagedSpaceOperation": FakeMoveWindows.self,
]

// MARK: - Suite

/// Move here brings a window over from another screen's Desktop
/// (#2770), and finds the shown Desktop where every Desktop sits
/// under one shared display id. Topology: the #888 fixture — Space
/// 1 on screen 1 (Desktop 10 shown, 11 away), Space 5 on screen 2
/// (Desktop 20 shown, 21 away).
@Suite("Move here across screens (#2770)", .serialized)
@MainActor
struct JumpMoveHereCrossScreenTests {
    private let pid: pid_t = 900_200
    private let bundle = "app.test.notes"

    private func makeCore(
        spaces: [NativeSpace] = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
    ) -> KiwiCore {
        Bridge.moves = []
        NativeSpaces.spacesOverride = spaces
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { bridgeClasses[$0] }
        let core = makeTestCore()
        for (id, name) in [(1, "A"), (2, "B")] {
            core.state.workspaces.upsertDisplay(
                Display(id: DisplayID(UInt32(id)), name: name, frame: .zero)
            )
        }
        for space in ["1", "2", "5"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.assign("1", to: DisplayID(1))
        core.state.workspaces.assign("2", to: DisplayID(1))
        core.state.workspaces.assign("5", to: DisplayID(2))
        core.state.workspaces.activate("1")
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    /// Window 7, up on native Space `host`, remembered in Space 2.
    private func park(_ core: KiwiCore, on host: UInt64) {
        core.state.awayWindows[WindowID(7)] = AwayWindow(
            id: WindowID(7),
            pid: pid,
            appName: "Notes",
            appBundleID: bundle,
            nativeSpace: host
        )
        core.state.rememberedSpaces[WindowID(7)] = .departed("2")
        let entry = DesktopCensus.Host(space: host, pid: pid, isUp: true)
        core.desktopMemory.readCensus = { spaces in
            DesktopCensus(
                hosts: [WindowID(7): entry],
                shown: Set(spaces.filter(\.isCurrent).map(\.id))
            )
        }
    }

    @Test("Move here hops a window from the other screen's Desktop")
    func hopsAcrossScreens() {
        let core = makeCore()
        defer { teardown() }
        park(core, on: 11)
        #expect(core.moveHere(.window(WindowID(7)), on: DisplayID(2)))
        #expect(Bridge.moves.map(\.1) == [20])
        #expect(core.state.rememberedSpaces[WindowID(7)] == .departed("5"))
        #expect(core.jump.owed?.space == "5")
        #expect(core.state.workspaces.activeSpace == "5")
    }

    /// A float's capture is the place it left on the other
    /// screen: delivered on its return, it pulled the window and its
    /// ring back there. An unread screen keeps it.
    @Test("a capture left on another screen is stale")
    func captureElsewhere() {
        let one = DisplayID(1)
        let two = DisplayID(2)
        #expect(KiwiCore.captureIsElsewhere(arriving: two, left: one))
        #expect(!KiwiCore.captureIsElsewhere(arriving: one, left: one))
        #expect(!KiwiCore.captureIsElsewhere(arriving: nil, left: one))
        #expect(!KiwiCore.captureIsElsewhere(arriving: two, left: nil))
    }

    /// `gather` keeps its screen: another screen's Desktop is not
    /// what "every window of this app here" reaches.
    @Test("gather leaves the other screen's Desktop alone")
    func gatherKeepsItsScreen() {
        let core = makeCore()
        defer { teardown() }
        core.state.workspaces.activate("5")
        park(core, on: 11)
        _ = core.execute("gather", args: [.string(bundle)])
        #expect(Bridge.moves.isEmpty)
        #expect(core.state.rememberedSpaces[WindowID(7)] == .departed("2"))
    }

    /// "Displays have separate Spaces" off: every Desktop is filed
    /// under one shared id no screen's UUID names.
    @Test("one shared Desktop set still finds the shown Desktop")
    func sharedDesktopsHop() {
        let core = makeCore(spaces: [
            authoritySpace(10, display: "Main", current: true),
            authoritySpace(11, display: "Main"),
        ])
        defer { teardown() }
        park(core, on: 11)
        #expect(core.moveHere(.window(WindowID(7))))
        #expect(Bridge.moves.map(\.1) == [10])
        #expect(core.state.rememberedSpaces[WindowID(7)] == .departed("1"))
    }

    /// Landed off `target`'s screen — the net re-homed it, or one
    /// shared Desktop set left its frame where it was — the owed
    /// focus still files it into the panel's Space.
    @Test("a hop that lands elsewhere is filed into the target")
    func landingElsewhereRelocates() {
        let core = makeCore()
        defer { teardown() }
        park(core, on: 11)
        #expect(core.moveHere(.window(WindowID(7)), on: DisplayID(2)))
        core.state.rememberedSpaces[WindowID(7)] = .departed("1")
        core.handle(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(7),
                    pid: pid,
                    appName: "Notes",
                    appBundleID: bundle
                )
            )
        )
        #expect(core.state.workspaces.space(of: WindowID(7)) == "5")
        #expect(core.state.workspaces.lastFocused == WindowID(7))
    }

    @Test("the hop's screen key refuses a screen the reading lacks")
    func hopDisplayKey() {
        let core = makeCore()
        defer { teardown() }
        func snapshot(
            _ current: [String: UInt64],
            main: String? = nil
        ) -> DesktopSnapshot {
            DesktopSnapshot(
                authority: nil,
                mainUUID: main,
                mainCurrentSpace: nil,
                currentSpaces: current,
                spaces: current.map {
                    authoritySpace($0.value, display: $0.key, current: true)
                }
            )
        }
        let two = snapshot(["UUID-A": 10, "UUID-B": 20], main: "UUID-A")
        #expect(core.hopDisplayKey(for: "5", in: two) == "UUID-B")
        // Screen 2 dropped from the reading: no landing on screen 1.
        let one = snapshot(["UUID-A": 10], main: "UUID-A")
        #expect(core.hopDisplayKey(for: "5", in: one) == nil)
        // A Space with no screen yet lands on the main one.
        #expect(core.hopDisplayKey(for: "9", in: two) == "UUID-A")
        // One shared Desktop set, under an id no screen answers to.
        let shared = snapshot(["Main": 10], main: "UUID-A")
        #expect(core.hopDisplayKey(for: "5", in: shared) == "Main")
        // A screen not tracked yet is the main one, not a shared set.
        let untracked = snapshot(["UUID-C": 30], main: "UUID-C")
        #expect(core.hopDisplayKey(for: "5", in: untracked) == nil)
    }
}
