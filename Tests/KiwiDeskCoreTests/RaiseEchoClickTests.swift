import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-echo-click-\(UUID().uuidString)"
        )
    let core = makeTestCore(configDirectory: directory)
    // Pin the display (tests.md / #531): the fall-through path
    // retiles, and its geometry must not be the host's screen.
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 25, width: 1440, height: 875)
    }
    return core
}

/// Three windows on one space: `intended` focused, the other two
/// overlapping each other (an edge pile's shape) and stamped in
/// the raise-echo ledger, as a z-order restore leaves them.
@MainActor
private func makePile(
    _ core: KiwiCore
) -> (intended: WindowID, top: WindowID, under: WindowID) {
    let frames: [CGRect] = [
        CGRect(x: 0, y: 0, width: 400, height: 300),
        CGRect(x: 500, y: 0, width: 400, height: 300),
        CGRect(x: 450, y: 0, width: 400, height: 300),
    ]
    for id in 1...3 {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: pid_t(id),
                    appName: "App\(id)",
                    frame: frames[id - 1]
                )
            )
        )
    }
    let intended = WindowID(1)
    let space = core.state.workspaces.space(of: intended)!
    core.state.workspaces.focus(intended, in: space)
    _ = core.stampZOrderRaise(
        [WindowID(2), WindowID(3)],
        excluding: intended
    )
    return (intended, WindowID(2), WindowID(3))
}

@MainActor
private func focused(_ core: KiwiCore) -> WindowID? {
    core.activeSpace?.focused
}

/// A point inside BOTH pile frames — where containment alone
/// cannot say which window a click reached.
private let overlapPoint = CGPoint(x: 600, y: 100)

/// #687: a genuine click on a window a z-order restore stamped is
/// shaped exactly like the restore's own raise echo, so the
/// revert consumed it — the ring and pan stayed behind while
/// macOS focused the clicked window. A recent click that REACHED
/// the reported window (inside its frame AND frontmost at that
/// point) is provenance no echo can forge, so it escapes the
/// revert. Containment alone is not enough: pile frames overlap,
/// so the escape resolves the tie through the stacking read.
@Suite("Raise-echo revert vs. clicks (#687)", .serialized)
@MainActor
struct RaiseEchoClickTests {
    @Test("A clickless stamped report is reverted")
    func echoWithoutClickReverts() {
        let core = makeCore()
        let (intended, top, _) = makePile(core)
        core.stackingOrderProvider = { [top] }
        core.handle(.windowFocused(top))
        #expect(focused(core) == intended)
        // Consumed: the echo the stamp promised has arrived.
        #expect(core.zOrderRaiseEchoes[top] == nil)
    }

    @Test("A click that reached the window escapes the revert")
    func clickOnReportedWindowIsHonored() {
        let core = makeCore()
        let (intended, top, under) = makePile(core)
        core.lastLeftClick = (Date(), overlapPoint)
        core.stackingOrderProvider = {
            [top, under, intended]
        }
        core.handle(.windowFocused(top))
        #expect(focused(core) == top)
        // The stamp survives the escape: the raise's real echo
        // may still be in flight, and if focus has moved on by
        // then, that echo must still be reverted.
        #expect(core.zOrderRaiseEchoes[top] != nil)
    }

    /// The reason the escape is stricter than containment: the
    /// click point sits inside BOTH pile frames, and the report
    /// under test is the UNDER window's late echo. Honoring it
    /// would pan the row onto a window the user did not click.
    @Test("A buried pile-mate's echo is still reverted")
    func buriedPileMateEchoReverts() {
        let core = makeCore()
        let (intended, top, under) = makePile(core)
        core.lastLeftClick = (Date(), overlapPoint)
        core.stackingOrderProvider = {
            [top, under, intended]
        }
        core.handle(.windowFocused(under))
        #expect(focused(core) == intended)
    }

    @Test("A click outside the reported window is no provenance")
    func clickOutsideFrameReverts() {
        let core = makeCore()
        let (intended, top, _) = makePile(core)
        core.lastLeftClick = (
            Date(), CGPoint(x: 100, y: 100)
        )
        core.stackingOrderProvider = { [top] }
        core.handle(.windowFocused(top))
        #expect(focused(core) == intended)
    }

    @Test("A click older than the echo window is no provenance")
    func staleClickReverts() {
        let core = makeCore()
        let (intended, top, _) = makePile(core)
        core.lastLeftClick = (
            Date().addingTimeInterval(
                -KiwiCore.zOrderRaiseEchoWindow - 0.1
            ),
            overlapPoint
        )
        core.stackingOrderProvider = { [top] }
        core.handle(.windowFocused(top))
        #expect(focused(core) == intended)
    }

    /// An unwired stacking provider answers "unknown", which is
    /// no provenance — the revert must behave exactly as before
    /// rather than trusting containment alone.
    @Test("No stacking provider means no escape")
    func unwiredProviderReverts() {
        let core = makeCore()
        let (intended, top, _) = makePile(core)
        core.lastLeftClick = (Date(), overlapPoint)
        core.handle(.windowFocused(top))
        #expect(focused(core) == intended)
    }
}
