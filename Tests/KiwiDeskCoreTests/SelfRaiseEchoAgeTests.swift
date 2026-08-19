import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-echo-age-\(UUID().uuidString)"
        )
    let core = makeTestCore(configDirectory: directory)
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 25, width: 1440, height: 875)
    }
    return core
}

/// Two windows in a scrolling space (the mode whose deferred
/// raise gives the self-echo revert its teeth), focus on `other`,
/// and `target` carrying an outstanding self-raise entry.
@MainActor
private func makeFixture(
    _ core: KiwiCore
) -> (target: WindowID, other: WindowID) {
    for id in 1...2 {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: pid_t(id),
                    appName: "App\(id)",
                    frame: CGRect(
                        x: 500 * CGFloat(id - 1),
                        y: 0,
                        width: 400,
                        height: 300
                    )
                )
            )
        )
    }
    let target = WindowID(1)
    let other = WindowID(2)
    let space = core.state.workspaces.space(of: target)!
    _ = core.execute(
        "set_mode",
        args: [.string(space.raw), .string("scrolling")]
    )
    core.state.workspaces.focus(other, in: space)
    core.outstandingSelfRaises.insert(target)
    return (target, other)
}

@MainActor
private func focused(_ core: KiwiCore) -> WindowID? {
    core.activeSpace?.focused
}

/// The self-echo revert's age bound (#687 device QA): a raise of
/// an already-key window emits NO echo — the restore's closing
/// re-assert does exactly that — so its `outstandingSelfRaises`
/// entry sat unconsumed forever, and the user's next click on
/// that window was classified as KiwiDesk's own raise echo and
/// reverted. It was the last unbounded ledger; the entry is our
/// echo only while `selfRaiseStamps` says the raise is recent.
@Suite("Self-raise echo age bound (#687)", .serialized)
@MainActor
struct SelfRaiseEchoAgeTests {
    @Test("A stale outstanding entry cannot eat a focus report")
    func staleEntryReportIsHonored() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        // No selfRaiseStamps entry at all — the raise is older
        // than the prune window, which is how a no-echo raise
        // looks once anything else has raised since.
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
        // Consumed either way — the set must not accrete.
        #expect(!core.outstandingSelfRaises.contains(target))
    }

    /// The arm this bound must NOT loosen: a recent raise's echo
    /// arriving after focus moved on is still reverted — the
    /// deferred-raise contract (#143/#152).
    @Test("A fresh entry's echo is still reverted")
    func freshEntryEchoStillReverts() {
        let core = makeCore()
        let (target, other) = makeFixture(core)
        core.selfRaiseStamps[target] = Date()
        core.handle(.windowFocused(target))
        #expect(focused(core) == other)
    }

    /// And even a fresh entry stands down for click provenance:
    /// a click that reached the window inside the ~1 s echo
    /// window of a no-echo re-assert must not be eaten.
    @Test("A fresh entry yields to a click that reached it")
    func freshEntryYieldsToClick() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.selfRaiseStamps[target] = Date()
        core.lastLeftClick = (
            Date(), CGPoint(x: 100, y: 100), target
        )
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
    }
}

/// Bar strips absorb a press (#687 device QA): a press inside a
/// painted bar landed on KiwiDesk's own overlay, which is absent
/// from state — resolving THROUGH it handed the window beneath a
/// provenance it never earned, letting a bar click near a
/// stamped pile escape that pile-mate's echo revert.
@Suite("Bar strips absorb click provenance (#687)", .serialized)
@MainActor
struct BarStripAbsorptionTests {
    @Test("A press inside a painted bar strip resolves nothing")
    func barPressResolvesNil() {
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "A",
                    frame: CGRect(
                        x: 0,
                        y: 0,
                        width: 800,
                        height: 600
                    )
                )
            )
        )
        core.stackingOrderProvider = { [WindowID(1)] }
        let inWindow = CGPoint(x: 400, y: 16)
        // Sanity: without a bar the press resolves the window.
        #expect(
            core.clickReachedWindow(at: inWindow) == WindowID(1)
        )
        core.appBars.sync([
            AppBarManager.Bar(
                display: DisplayID(1),
                space: core.state.workspaces.activeSpace
                    ?? SpaceID("1"),
                items: [
                    AppBarOverlay.Item(
                        id: WindowID(1),
                        name: "A",
                        text: "A",
                        icon: nil
                    )
                ],
                activeIndex: 0,
                strip: CGRect(
                    x: 0,
                    y: 0,
                    width: 800,
                    height: 32
                ),
                style: AppBarStyle()
            )
        ])
        // The same point now sits inside the painted strip —
        // the bar absorbed the press.
        #expect(core.clickReachedWindow(at: inWindow) == nil)
        // A press below the strip still resolves.
        #expect(
            core.clickReachedWindow(
                at: CGPoint(x: 400, y: 300)
            ) == WindowID(1)
        )
    }

    /// The Space Bar arm of the same mask — proven separately
    /// because dropping it from the absorption check left every
    /// other suite green (guard-prover, 2026-08-03).
    @Test("A press inside a Space Bar strip resolves nothing")
    func spaceBarPressResolvesNil() {
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "A",
                    frame: CGRect(
                        x: 0,
                        y: 500,
                        width: 800,
                        height: 400
                    )
                )
            )
        )
        core.stackingOrderProvider = { [WindowID(1)] }
        let inStrip = CGPoint(x: 400, y: 880)
        #expect(
            core.clickReachedWindow(at: inStrip) == WindowID(1)
        )
        core.spaceBars.sync([
            SpaceBarManager.Bar(
                display: DisplayID(1),
                items: [
                    SpaceBarOverlay.Item(
                        space: core.state.workspaces
                            .activeSpace ?? SpaceID("1"),
                        spaceGlyph: .text("1", tinted: true),
                        apps: [],
                        active: true,
                        overflow: 0,
                        focusInOverflow: false
                    )
                ],
                strip: CGRect(
                    x: 0,
                    y: 860,
                    width: 800,
                    height: 40
                ),
                style: SpaceBarStyle(),
                stateMarkColors: StateMarkColors(
                    sticky: "",
                    floating: ""
                )
            )
        ])
        #expect(core.clickReachedWindow(at: inStrip) == nil)
        #expect(
            core.clickReachedWindow(
                at: CGPoint(x: 400, y: 600)
            ) == WindowID(1)
        )
    }
}
