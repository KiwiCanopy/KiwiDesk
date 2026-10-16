import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A scroll gesture skips like the keys (#2103 ruling 45): ⌃⌥ +
/// scroll steps past the windows a lens keeps hazed on both of its
/// routes — the arrow keys' `navigate` for a Scrolling row or a
/// Monocle stack, the Space's own order everywhere else.
@Suite("KiwiVision lens scroll gesture", .serialized)
@MainActor
struct KiwiVisionLensGestureTests {
    private let member = "test.kiwi.notes"

    /// Windows 1 and 3 are the lens's app, 2 another app's; 1 has
    /// the focus.
    private func makeCore(
        _ mode: String
    ) -> (KiwiCore, ScrollPanSession) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.eventLoop.ownKeyWindow = { nil }
        for (id, bundle) in [
            (1, member), (2, "test.kiwi.other"), (3, member),
        ] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: 900_032,
                        appName: "App",
                        appBundleID: bundle
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string(mode)]
        )
        let lens: [String: JSONValue] = [
            "name": .string("Writing"),
            "apps": .array([.string(member)]),
        ]
        core.execute("kiwivision.define_lens", args: [.object(lens)])
        let session = ScrollPanSession()
        session.spaceAt = { _, _ in space }
        return (core, session)
    }

    /// One swipe bringing the next window in, from window 1.
    private func swipeNext(
        _ core: KiwiCore,
        _ session: ScrollPanSession
    ) -> WindowID? {
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.state.workspaces.focus(WindowID(1), in: space)
        for kind in [ScrollGestureEvent.Kind.began, .changed, .ended] {
            core.handleScrollPan(
                ScrollGestureEvent(
                    chord: [.control, .option],
                    kind: kind,
                    input: .trackpad,
                    delta: CGVector(dx: kind == .changed ? -80 : 0, dy: 0),
                    momentum: false,
                    location: .zero,
                    time: 0
                ),
                session: session
            )
        }
        return core.activeSpace?.focused
    }

    @Test(
        "a swipe skips the other app's window",
        arguments: ["scrolling", "monocle", "bsp", "grid"]
    )
    func swipeSkips(mode: String) {
        let (core, session) = makeCore(mode)
        #expect(swipeNext(core, session) == WindowID(2))
        core.setKiwiVision(.lens("Writing"))
        #expect(swipeNext(core, session) == WindowID(3))
    }
}
