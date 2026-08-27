import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A scrolling space of twenty 800pt slots. Twenty overflow every
/// display, so a focus ten slots in leaves both clamps far away
/// on any of them — only the re-anchor can move that window.
@MainActor
private func makeScrollingCore() throws -> (
    core: KiwiCore, space: SpaceID
) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    let core = makeTestCore(configDirectory: directory)
    for id in 1...20 {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: pid_t(id),
                    appName: "App\(id)"
                )
            )
        )
    }
    let space = try #require(
        core.state.workspaces.space(of: WindowID(1))
    )
    core.execute(
        "set_mode",
        args: [.string(space.raw), .string("scrolling")]
    )
    core.execute("scroll.set_slot_size", args: [.number(800)])
    return (core, space)
}

/// Focuses `window`, retiles, then parks its slot `lead` points
/// into the viewport — the repro's shape (its leading neighbour
/// clipped) and clear of every clamp on any display width.
/// Returns the row position the rest was measured against.
@MainActor
private func seedLead(
    _ lead: CGFloat,
    on window: WindowID,
    of space: SpaceID,
    _ core: KiwiCore
) throws -> CGFloat {
    core.state.workspaces.focus(window, in: space)
    core.retile(animated: false)
    let position = try #require(
        core.activeSpace?.scrollRest?.slot?.position
    )
    core.state.workspaces.withSpace(space) {
        $0.scrollRest = ScrollRest(
            offset: -position + lead,
            focus: window,
            position: position
        )
    }
    return position
}

/// The same fix at production altitude: the `resize` verb, the
/// rest `KiwiCore.persistScrollRest` stores, and the retile in
/// between. The layout suite above pins the maths on a fixed
/// display; this one asserts only the invariant the fix exists
/// for — the focused window keeps its place on screen — so it
/// holds on whatever display the host has (#450).
///
/// It is also the ONLY net for the producer half — the layout
/// suite above injects `context.scrollRest` by hand, so a
/// `viewportRest` that stopped recording the slot leaves every
/// one of those green (guard-prover, 2026-08-27). Hence the
/// screen requirement is an `.enabled(if:)` trait rather than an
/// early `return`: on a headless host this must read as a visible
/// SKIP, never as a green that asserted nothing.
@Suite(
    "Scrolling resize re-anchor, end to end (#966)",
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ScrollingResizeAnchorEndToEndTests {
    @Test("The resize verb keeps the focused window in place")
    func resizeVerbKeepsFocusedWindowInPlace() throws {
        let (core, space) = try makeScrollingCore()
        let focus = WindowID(10)
        let seeded = try seedLead(40, on: focus, of: space, core)

        core.execute("resize", args: [.string("x"), .number(-100)])

        let after = try #require(core.activeSpace?.scrollRest)
        let position = try #require(after.slot?.position)
        #expect(after.slot?.window == focus)
        // The row really did move underneath the focus...
        #expect(position < seeded)
        // ...and the focused window did not.
        #expect(abs(after.offset + position - 40) < 0.5)
    }

    @Test("Swapping the focus along the row holds its place")
    func swapHoldsTheFocusedWindowInPlace() throws {
        // `swap` re-seats the focused window in the array, which
        // moves its slot without changing which window is
        // focused — so it takes the re-anchor arm, and the
        // window the user is acting on stays put while the row
        // slides past it. Ruled deliberately (#966): no signal
        // inside the layout can separate this from a neighbour
        // closing ahead of the focus, and the same answer is the
        // right one for both — the thing being acted on is the
        // thing that must not jump.
        let (core, space) = try makeScrollingCore()
        let focus = WindowID(10)
        let seeded = try seedLead(40, on: focus, of: space, core)

        #expect(
            core.execute("swap", args: [.string("right")])
                .isSuccess
        )
        let after = try #require(core.activeSpace?.scrollRest)
        let position = try #require(after.slot?.position)
        #expect(after.slot?.window == focus)
        // The window moved one slot further along the row...
        #expect(position > seeded)
        // ...and did not move on screen.
        #expect(abs(after.offset + position - 40) < 0.5)
    }
}
