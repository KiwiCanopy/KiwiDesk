import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let core = makeTestCore(
        configDirectory:
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwidesk-screen-handoff-\(UUID().uuidString)"
            )
    )
    // Pin the display (tests.md / #531): the window's slot is
    // the warp target, and must not be the host's screen.
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 25, width: 1440, height: 875)
    }
    return core
}

private func window(_ id: UInt32) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: pid_t(900_000 + id),
        appName: "App\(id)",
        frame: CGRect(x: 0, y: 0, width: 400, height: 300)
    )
}

/// The screen handoff (#2548): a Space switch that moves focus
/// onto another screen moves the pointer there with the setting
/// off, and nothing else does. Space 1 sits on a screen no
/// `NSScreen` backs, Spaces 2 and 3 on the host's main screen —
/// the window's slot and the empty Space's frame are resolved
/// through a real screen, so a screenless runner skips.
@Suite("Screen handoff (#2548)", .serialized)
@MainActor
struct ScreenHandoffTests {
    private let away = DisplayID(9_999)

    private func twoScreenCore() -> (KiwiCore, DisplayID)? {
        guard let main = ScreenList.all.first?.kiwiDisplayID
        else { return nil }
        let core = makeCore()
        core.state.workspaces.assign(SpaceID("1"), to: away)
        core.state.workspaces.assign(SpaceID("2"), to: main)
        core.state.workspaces.assign(SpaceID("3"), to: main)
        core.state.workspaces.activate(SpaceID("2"))
        core.state.apply(.windowCreated(window(2)))
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(.windowCreated(window(1)))
        core.state.apply(.windowFocused(WindowID(1)))
        return (core, main)
    }

    @Test("the pure gate hands off only across screens")
    func pureGate() {
        let a = DisplayID(1)
        let b = DisplayID(2)
        let win = CGRect(x: 10, y: 10, width: 100, height: 100)
        let scr = CGRect(x: 0, y: 0, width: 800, height: 600)
        func frame(
            _ prior: DisplayID?,
            _ target: DisplayID?,
            _ pointer: DisplayID?,
            _ window: CGRect?
        ) -> CGRect? {
            ScreenHandoff.frame(
                from: prior,
                to: target,
                pointerOn: pointer,
                window: window,
                screen: scr
            )
        }
        #expect(frame(a, b, a, win) == win)
        #expect(frame(a, b, a, nil) == scr)
        #expect(frame(a, b, nil, win) == win)
        #expect(frame(a, b, b, win) == nil)
        #expect(frame(a, a, b, win) == nil)
        #expect(frame(nil, b, a, win) == nil)
        #expect(frame(a, nil, a, win) == nil)
    }

    @Test("a switch onto another screen warps with the setting off")
    func crossingWarps() throws {
        guard let (core, _) = twoScreenCore() else { return }
        #expect(!core.tiler.settings.mouse.followsFocus)
        core.mouse.pointerDisplay = { self.away }
        var warped: [CGRect] = []
        core.pointerWarp = { warped.append($0) }
        core.execute("focus_space", args: [.string("2")])
        let slot = try #require(
            core.tiler.calculatedFrames(state: core.state)[
                WindowID(2)
            ]
        )
        #expect(warped == [slot])
    }

    @Test("an empty Space on another screen takes its centre")
    func emptySpaceTakesTheScreen() throws {
        guard let (core, main) = twoScreenCore() else { return }
        core.mouse.pointerDisplay = { self.away }
        var warped: [CGRect] = []
        core.pointerWarp = { warped.append($0) }
        core.execute("focus_space", args: [.string("3")])
        let screen = try #require(core.handoffScreenFrame(of: main))
        #expect(warped == [screen])
    }

    @Test("a pointer already on the target screen stays")
    func pointerOnTargetStays() {
        guard let (core, main) = twoScreenCore() else { return }
        core.mouse.pointerDisplay = { main }
        var warps = 0
        core.pointerWarp = { _ in warps += 1 }
        core.execute("focus_space", args: [.string("2")])
        #expect(warps == 0)
    }

    @Test("a same-screen switch is the setting's, a held button none")
    func sameScreenAndHeldButton() {
        guard let (core, _) = twoScreenCore() else { return }
        core.mouse.pointerDisplay = { self.away }
        var warps = 0
        core.pointerWarp = { _ in warps += 1 }
        core.execute("focus_space", args: [.string("2")])
        #expect(warps == 1)
        // Space 2 → 3 stays on the main screen: setting off.
        core.execute("focus_space", args: [.string("3")])
        #expect(warps == 1)
        core.execute("focus_space", args: [.string("1")])
        #expect(warps == 1)
        core.mouse.pressedButtons = { 1 }
        core.execute("focus_space", args: [.string("2")])
        #expect(warps == 1)
    }

    /// The pointer and frame reads run only where the focus crossed
    /// (guard-prover, #2548): a same-screen switch reads nothing.
    @Test("a same-screen switch reads no pointer")
    func sameScreenReadsNothing() {
        guard let (core, _) = twoScreenCore() else { return }
        var reads = 0
        core.mouse.pointerDisplay = {
            reads += 1
            return self.away
        }
        core.pointerWarp = { _ in }
        core.execute("focus_space", args: [.string("2")])
        #expect(reads == 1)
        reads = 0
        core.execute("focus_space", args: [.string("3")])
        #expect(reads == 0)
    }

    /// A follow whose focus the #1345 gate refuses moves no pointer.
    @Test("a refused follow moves no pointer")
    func refusedFollowStays() {
        guard let (core, _) = twoScreenCore() else { return }
        core.mouse.pointerDisplay = { self.away }
        core.windowIsOnScreen = { $0 == WindowID(1) ? false : nil }
        var warps = 0
        core.pointerWarp = { _ in warps += 1 }
        core.execute(
            "move_to_space_and_follow",
            args: [.string("3")]
        )
        #expect(warps == 0)
    }

    @Test("the scroll step never hands off")
    func scrollStepStays() {
        guard let (core, _) = twoScreenCore() else { return }
        core.mouse.pointerDisplay = { self.away }
        var warps = 0
        core.pointerWarp = { _ in warps += 1 }
        core.switchSpace(to: SpaceID("2"), warp: false)
        #expect(warps == 0)
    }

    @Test("a move-and-follow onto another screen hands off")
    func followHandsOff() {
        guard let (core, _) = twoScreenCore() else { return }
        core.mouse.pointerDisplay = { self.away }
        var warps = 0
        core.pointerWarp = { _ in warps += 1 }
        core.execute(
            "move_to_space_and_follow",
            args: [.string("3")]
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("3"))
        #expect(warps == 1)
    }
}
