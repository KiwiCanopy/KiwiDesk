import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A new window takes the focus at arrival only where its app holds
/// the keys (#3152 ▸ Ruling): read through the #1322 gate, driven
/// through `handle` with another app active, so a lost mirror reds
/// here and nowhere else (every other fixture has no active app and
/// fails open). Each let-out sits beside the case it differs from by
/// one input.
@Suite("A background window leaves the focus where it is (#3152)")
@MainActor
struct BackgroundArrivalFocusTests {
    static let here = "com.test.here"
    static let other = "com.test.background-app"

    /// A focused w1 of `here` (pid 900_601), that app active.
    static func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: testTemporaryDirectory.appendingPathComponent(
                "kiwi-arrival-focus-\(UUID().uuidString)"
            )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        arrive(1, pid: 900_601, bundleID: here, on: core)
        core.focusWindow(WindowID(1), warp: false)
        core.eventLoop.lastActivePid = 900_601
        return core
    }

    static func arrive(
        _ id: UInt32,
        pid: pid_t,
        bundleID: String,
        on core: KiwiCore
    ) {
        core.handle(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(id),
                    pid: pid,
                    appName: "App \(id)",
                    appBundleID: bundleID,
                    frame: CGRect(x: 0, y: 30, width: 400, height: 300)
                )
            )
        )
    }

    @Test("a background app's new window takes no focus")
    func backgroundWindowTakesNone() {
        let core = Self.makeCore()
        Self.arrive(7, pid: 900_607, bundleID: Self.other, on: core)
        #expect(core.state.windows[WindowID(7)] != nil)
        #expect(core.focusedWindowID == WindowID(1))
        #expect(core.state.arrivalFocus == .foreground)  // consumed
    }

    @Test("the active app's new window takes the focus")
    func foregroundWindowTakesIt() {
        let core = Self.makeCore()
        Self.arrive(7, pid: 900_601, bundleID: Self.here, on: core)
        #expect(core.focusedWindowID == WindowID(7))
    }

    /// The GUI fronts its own windows (#1281, #1414).
    @Test("KiwiDesk's own window takes the focus behind another app")
    func ownWindowTakesIt() {
        let core = Self.makeCore()
        Self.arrive(
            7,
            pid: ProcessInfo.processInfo.processIdentifier,
            bundleID: "com.kiwicanopy.kiwidesk",
            on: core
        )
        #expect(core.focusedWindowID == WindowID(7))
    }

    @Test("with no reading the gate fails open, as before")
    func noReadingGrants() {
        let core = Self.makeCore()
        core.eventLoop.lastActivePid = nil
        Self.arrive(7, pid: 900_607, bundleID: Self.other, on: core)
        #expect(core.focusedWindowID == WindowID(7))
    }

    /// The nil arm stays: a Space with no focus takes its first one.
    @Test("a background window into a focusless Space takes it")
    func focuslessSpaceTakesIt() {
        let core = Self.makeCore()
        let empty = SpaceID("2")
        core.state.workspaces.ensureSpace(empty)
        core.state.appRules[Self.other] = empty
        Self.arrive(7, pid: 900_607, bundleID: Self.other, on: core)
        #expect(core.state.workspaces[empty]?.focused == WindowID(7))
        #expect(core.focusedWindowID == WindowID(1))
    }

    /// The follow is untouched (#1599, #2478); a quiet open's is
    /// not, whatever its Space.
    @Test(
        "the fold's follow reads only the quiet case",
        arguments: [
            (ArrivalFocus.background, true),
            (ArrivalFocus.foreground, true),
            (ArrivalFocus.quiet(into: nil), false),
            (ArrivalFocus.quiet(into: SpaceID("3")), false),
        ]
    )
    func followByVerdict(focus: ArrivalFocus, follows: Bool) {
        var state = StateCoordinator()
        state.workspaces.ensureSpace(SpaceID("1"))
        state.workspaces.ensureSpace(SpaceID("2"))
        state.workspaces.ensureSpace(SpaceID("3"))
        state.appRules[Self.other] = SpaceID("2")
        state.arrivalFocus = focus
        let effects = state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(7),
                    pid: 900_607,
                    appName: "Other",
                    appBundleID: Self.other
                )
            )
        )
        let filed = state.workspaces.space(of: WindowID(7))
        #expect((effects.placedByAppRule != nil) == follows)
        #expect(
            filed
                == (focus == .quiet(into: SpaceID("3"))
                    ? SpaceID("3") : SpaceID("2"))
        )
    }
}
