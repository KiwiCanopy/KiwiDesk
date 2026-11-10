import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `open_in_background(bundle_id, space)` (#3152 ▸ Ruling
/// amendment): the app's windows are filed into the named Space
/// while its quiet mark stands, switching nothing; a refusal
/// launches nothing; the user taking the app ends the filing.
@Suite("open_in_background files into a named Space (#3152)", .serialized)
@MainActor
struct OpenInBackgroundSpaceTests {
    typealias F = OpenInBackgroundTests
    static let named = SpaceID("2")

    static func makeCore(
        running: Bool = false
    ) -> (KiwiCore, F.Recorder) {
        let (core, recorder) = F.makeCore(running: running)
        core.state.workspaces.ensureSpace(named)
        return (core, recorder)
    }

    @discardableResult
    static func open(
        _ core: KiwiCore,
        into space: JSONValue = .string("2")
    ) -> CommandResponse {
        core.execute(
            "open_in_background",
            args: [.string(F.app), space]
        )
    }

    @Test("every window of the app files into the named Space")
    func windowsFileThere() {
        let (core, _) = Self.makeCore()
        let home = core.state.workspaces.activeSpace
        #expect(Self.open(core).isSuccess)
        F.arrive(7, bundleID: F.app, on: core)
        F.arrive(8, bundleID: F.app, on: core)
        #expect(core.state.workspaces.space(of: WindowID(7)) == Self.named)
        #expect(core.state.workspaces.space(of: WindowID(8)) == Self.named)
        #expect(core.state.workspaces.activeSpace == home)
        #expect(core.focusedWindowID == WindowID(1))
    }

    @Test("a numeric Space id is the same Space")
    func numericIdMatches() {
        let (core, _) = Self.makeCore()
        #expect(Self.open(core, into: .number(2)).isSuccess)
        F.arrive(7, bundleID: F.app, on: core)
        #expect(core.state.workspaces.space(of: WindowID(7)) == Self.named)
    }

    /// Lua's `nil` reaches the verb as `.null`.
    @Test("a nil Space is no Space")
    func nilSpaceIsNone() {
        let (core, _) = Self.makeCore()
        let home = core.state.workspaces.activeSpace
        #expect(Self.open(core, into: .null).isSuccess)
        F.arrive(7, bundleID: F.app, on: core)
        #expect(core.state.workspaces.space(of: WindowID(7)) == home)
    }

    @Test("the named Space beats the app's own rule")
    func namedBeatsRule() {
        let (core, _) = Self.makeCore()
        core.state.workspaces.ensureSpace(SpaceID("3"))
        core.state.appRules[F.app] = SpaceID("3")
        #expect(Self.open(core).isSuccess)
        F.arrive(7, bundleID: F.app, on: core)
        #expect(core.state.workspaces.space(of: WindowID(7)) == Self.named)
    }

    @Test("an unknown Space is refused and launches nothing")
    func unknownSpaceRefused() {
        let (core, recorder) = Self.makeCore()
        let answer = Self.open(core, into: .string("9"))
        #expect(answer.error == "unknown space: 9")
        #expect(recorder.opened.isEmpty)
    }

    @Test("an app with a window refuses a named Space")
    func existingWindowRefused() {
        let (core, recorder) = Self.makeCore(running: true)
        F.arrive(7, bundleID: F.app, on: core)
        let answer = Self.open(core)
        #expect(answer.error?.contains("nothing was opened") == true)
        #expect(recorder.opened.isEmpty)
    }

    /// A profile switch inside the bound never re-creates it (#1230).
    @Test("a Space gone since the call is not re-created")
    func goneSpaceFallsThrough() {
        let (core, _) = Self.makeCore()
        let home = core.state.workspaces.activeSpace
        #expect(Self.open(core).isSuccess)
        core.state.workspaces.removeSpace(Self.named)
        F.arrive(7, bundleID: F.app, on: core)
        #expect(core.state.workspaces[Self.named] == nil)
        #expect(core.state.workspaces.space(of: WindowID(7)) == home)
    }

    @Test("a click on the app's window ends the filing")
    func userTakeEndsFiling() {
        let (core, _) = Self.makeCore()
        let home = core.state.workspaces.activeSpace
        #expect(Self.open(core).isSuccess)
        F.arrive(7, bundleID: F.app, on: core)
        core.lastLeftClick = (core.wallClock(), .zero, WindowID(7))
        core.handle(.windowFocused(WindowID(7)))
        F.arrive(8, bundleID: F.app, on: core)
        #expect(core.state.workspaces.space(of: WindowID(8)) == home)
    }

    @Test("Open or Focus on the app ends the filing")
    func namingEndsFiling() {
        let (core, _) = Self.makeCore()
        let home = core.state.workspaces.activeSpace
        #expect(Self.open(core).isSuccess)
        core.oweLaunchFollow(F.app, at: core.wallClock())
        F.arrive(7, bundleID: F.app, on: core)
        #expect(core.state.workspaces.space(of: WindowID(7)) == home)
    }

    @Test("past the quiet bound the filing ends")
    func boundEndsFiling() {
        let (core, _) = Self.makeCore()
        let home = core.state.workspaces.activeSpace
        #expect(Self.open(core).isSuccess)
        let late = core.wallClock().addingTimeInterval(
            LaunchFollowIntent.quietBound + 1
        )
        core.wallClock = { late }
        F.arrive(7, bundleID: F.app, on: core)
        #expect(core.state.workspaces.space(of: WindowID(7)) == home)
    }

    /// A paid hand-back leaves no hold, and the user's click still
    /// ends the filing.
    @Test("a click after a paid hand-back ends the filing")
    func clickAfterPaidHandBack() {
        let (core, _) = Self.makeCore()
        let home = core.state.workspaces.activeSpace
        #expect(Self.open(core).isSuccess)
        F.arrive(7, bundleID: F.app, on: core)
        core.handle(.windowFocused(WindowID(7)))
        // Paid: the click below finds no hold to spend.
        #expect(core.focusedWindowID == WindowID(1))
        #expect(core.launchFollow.holds.opened[F.app] == nil)
        core.lastLeftClick = (core.wallClock(), .zero, WindowID(7))
        core.handle(.windowFocused(WindowID(7)))
        F.arrive(8, bundleID: F.app, on: core)
        #expect(core.state.workspaces.space(of: WindowID(8)) == home)
    }

    /// The Space is the mark's: a later quiet open names none.
    @Test("a later quiet open does not inherit the named Space")
    func spaceEndsWithTheMark() {
        let (core, _) = Self.makeCore()
        let home = core.state.workspaces.activeSpace
        #expect(Self.open(core).isSuccess)
        let late = core.wallClock().addingTimeInterval(
            LaunchFollowIntent.quietBound + 1
        )
        core.wallClock = { late }
        core.launchFollow.noteQuietApps([F.app], at: late)
        F.arrive(7, bundleID: F.app, on: core)
        #expect(core.state.workspaces.space(of: WindowID(7)) == home)
    }

    /// The Dock's path: an activation door past a paid hand-back.
    @Test("a Dock click after a paid hand-back ends the filing")
    func dockClickAfterPaidHandBack() {
        let (core, _) = Self.makeCore()
        let home = core.state.workspaces.activeSpace
        #expect(Self.open(core).isSuccess)
        OpenInBackgroundHoldTests.activate(core)
        // Paid: the second activation finds no hold to spend.
        #expect(core.launchFollow.holds.opened[F.app] == nil)
        #expect(core.launchFollow.holds.handedBack[F.app] != nil)
        core.lastLeftClick = (core.wallClock(), .zero, nil)
        OpenInBackgroundHoldTests.activate(core)
        F.arrive(7, bundleID: F.app, on: core)
        #expect(core.state.workspaces.space(of: WindowID(7)) == home)
    }

    /// The rule's gate (#1602, #2475): a popup filed into an unshown
    /// Space is parked the moment it opens.
    @Test("a popup of the app skips the named Space")
    func popupSkipsNamedSpace() {
        let (core, _) = Self.makeCore()
        let home = core.state.workspaces.activeSpace
        #expect(Self.open(core).isSuccess)
        var popup = ManagedWindow(
            id: WindowID(7),
            pid: 900_307,
            appName: "App 7",
            appBundleID: F.app,
            frame: CGRect(x: 0, y: 30, width: 400, height: 300)
        )
        popup.isTransientOverlay = true
        popup.hasTitlebarButton = false
        #expect(popup.isPopup)
        core.handle(.windowCreated(popup))
        #expect(core.state.workspaces.space(of: WindowID(7)) == home)
    }

    @Test("the named Space ends with the mark's bound")
    func quietSpaceReadsTheBound() {
        let follow = LaunchFollowIntent()
        let start = Date(timeIntervalSince1970: 1_000)
        follow.noteQuietApps([F.app], at: start, into: Self.named)
        #expect(follow.quietSpace(F.app, at: start) == Self.named)
        let late = start.addingTimeInterval(LaunchFollowIntent.quietBound + 1)
        #expect(follow.quietSpace(F.app, at: late) == nil)
    }
}
