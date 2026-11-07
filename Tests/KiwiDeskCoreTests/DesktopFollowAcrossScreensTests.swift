import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The set lands as the WindowServer's reads measured it: the target
/// is shown before the eager departure's fold reads the topology.
private final class ShowingSetCurrentSpace: NSObject {
    @objc(initWithDisplayIdentifier:spaceID:)
    init(displayIdentifier: String, spaceID: UInt64) {}

    @objc func performWithWMBridgeDelegate() {
        MainActor.assumeIsolated {
            NativeSpaces.spacesOverride = authorityTopology(
                mainCurrent: 10,
                secondaryCurrent: 21
            )
        }
    }
}

/// A follow onto another screen's hidden Desktop, through the real
/// dispatch and fold (#3052). Two routes brought the window home: the
/// departure read as a close, and the arrival judged by an AX frame
/// still on the screen it left.
///
/// The host's own first screen stands in for the target's, and the
/// stale AX frame sits on no screen, since a test host may have one.
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests` applies.
@Suite("A follow across screens lands there (#3052)", .serialized)
@MainActor
struct DesktopFollowAcrossScreensTests {
    private let moved = WindowID(7)
    private let pid: pid_t = 900_001
    private let there = SpaceID("there")
    private let stale = CGRect(x: -100_000, y: 0, width: 800, height: 600)
    private let farScreen = DisplayID(UInt32.max)

    private func makeCore() throws -> (KiwiCore, CGRect) {
        DesktopVerbBridge.reset()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = {
            $0 == "ManagedDisplaySetCurrentSpaceOperation"
                ? ShowingSetCurrentSpace.self
                : desktopVerbBridgeClasses[$0]
        }
        let core = makeTestCore()
        let screen = try #require(ScreenList.all.first)
        let shown = try #require(screen.kiwiDisplayID)
        core.state.workspaces.upsertDisplay(
            Display(id: farScreen, name: "Far", frame: stale)
        )
        core.state.workspaces.upsertDisplay(
            Display(id: shown, name: "Near", frame: screen.frame)
        )
        core.state.workspaces.assign("1", to: farScreen)
        core.state.workspaces.assign(there, to: shown)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: moved, pid: pid, appName: "App")
            )
        )
        core.state.apply(.windowFocused(moved))
        return (core, GeometryUtils.axVisibleFrame(of: screen))
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    private func arrive(_ core: KiwiCore) {
        core.handle(
            .windowCreated(
                ManagedWindow(
                    id: moved,
                    pid: pid,
                    appName: "App",
                    frame: stale
                )
            )
        )
    }

    private func follow(_ core: KiwiCore, _ args: [JSONValue]) -> Bool {
        core.execute("move_to_desktop_and_follow", args: args).isSuccess
    }

    @Test("the departure reads as the move, with the target shown")
    func departureIsNoClose() throws {
        let (core, _) = try makeCore()
        defer { teardown() }
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        // The read the race answers with: hosted on a shown Desktop.
        core.desktopMemory.readWindowSpace = { _ in .hosted(21) }
        #expect(follow(core, [.number(4)]))
        #expect(!core.state.closedDepartures.contains(moved))
        #expect(core.state.rememberedSpaces[moved] == .departed("1"))
        #expect(core.state.awayWindows[moved]?.nativeSpace == 21)
        #expect(!lines.contains { $0.contains("still hosted") })
    }

    @Test("the arrival takes the Space the target's screen shows")
    func trackedLandsThere() throws {
        let (core, frame) = try makeCore()
        defer { teardown() }
        core.windowServer.readWindowBounds = { _ in frame }
        #expect(follow(core, [.number(4)]))
        arrive(core)
        #expect(core.state.workspaces.space(of: moved) == there)
        #expect(core.state.workspaces.activeSpace == there)
        #expect(core.focusedWindowID == moved)
    }

    /// No departure to misread, so only the frame can fail it.
    @Test("an away window's arrival takes it too")
    func awayLandsThere() throws {
        let (core, frame) = try makeCore()
        defer { teardown() }
        core.state.apply(.windowDestroyed(moved, wasMinimized: false))
        core.state.rememberedSpaces[moved] = .departed("1")
        core.state.awayWindows[moved] = AwayWindow(
            id: moved,
            pid: pid,
            appName: "App",
            appBundleID: "com.example.app",
            title: "Elsewhere",
            nativeSpace: 11
        )
        core.windowServer.readWindowBounds = { _ in frame }
        let id = JSONValue.number(Double(moved.raw))
        #expect(follow(core, [.number(4), .null, id]))
        arrive(core)
        #expect(core.state.workspaces.space(of: moved) == there)
        #expect(core.state.workspaces.activeSpace == there)
        #expect(core.focusedWindowID == moved)
    }

    /// The verb's word is about its own window: a window its app
    /// stops listing on a shown Desktop is closed, as it ever was.
    @Test("a removal outside the follow still reads as a close")
    func plainRemovalCloses() throws {
        let (core, _) = try makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(10) }
        core.handle(.windowDestroyed(moved, wasMinimized: false))
        #expect(core.state.closedDepartures.contains(moved))
        #expect(core.state.awayWindows[moved] == nil)
    }

    /// A Lua handler can close another window inside the span.
    @Test("another window's removal inside the span still reads a close")
    func otherWindowInSpanCloses() throws {
        let (core, _) = try makeCore()
        defer { teardown() }
        let other = WindowID(8)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: other, pid: pid, appName: "App")
            )
        )
        core.desktopMemory.readWindowSpace = { _ in .hosted(10) }
        core.eventLoop.eagerDepartureInFlight = (moved, 21)
        core.handle(.windowDestroyed(other, wasMinimized: false))
        core.eventLoop.eagerDepartureInFlight = nil
        #expect(core.state.closedDepartures.contains(other))
    }

    /// No census stands behind an entry filed without an answer, so it
    /// would never be pruned (#1234's shape).
    @Test("with no compositor answer the departure files no entry")
    func noAnswerFilesNoEntry() throws {
        let (core, _) = try makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .unavailable }
        #expect(follow(core, [.number(4)]))
        #expect(core.state.awayWindows[moved] == nil)
        #expect(!core.state.closedDepartures.contains(moved))
    }

    @Test("the eager departure's latch ends with its span")
    func latchIsASpan() throws {
        let (core, _) = try makeCore()
        defer { teardown() }
        #expect(follow(core, [.number(4)]))
        #expect(core.eventLoop.eagerDepartureInFlight == nil)
    }

    /// Only a departed window's screen is judged by the compositor:
    /// a new window takes its own frame, and asks no read for it.
    @Test("the arrival frame reads the compositor only for a departure")
    func arrivalFrameArms() throws {
        let (core, frame) = try makeCore()
        defer { teardown() }
        var reads = 0
        core.windowServer.readWindowBounds = { _ in
            reads += 1
            return frame
        }
        let window = ManagedWindow(
            id: WindowID(8),
            pid: pid,
            appName: "App",
            frame: stale
        )
        #expect(core.arrivalFrame(of: window) == stale)
        #expect(reads == 0)
        core.state.rememberedSpaces[window.id] = .restored("1")
        #expect(core.arrivalFrame(of: window) == stale)
        #expect(reads == 0)
        core.state.rememberedSpaces[window.id] = .departed("1")
        #expect(core.arrivalFrame(of: window) == frame)
        core.state.workspaces.removeDisplay(farScreen)
        let oneScreen = reads
        #expect(core.arrivalFrame(of: window) == stale)
        #expect(reads == oneScreen)
        core.state.workspaces.upsertDisplay(
            Display(id: farScreen, name: "Far", frame: stale)
        )
        core.windowServer.readWindowBounds = { _ in nil }
        #expect(core.arrivalFrame(of: window) == stale)
    }
}
