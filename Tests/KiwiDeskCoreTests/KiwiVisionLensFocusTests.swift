import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A lens keeps the keys on its apps (#2103 rulings 30, 35): while
/// it is on with "Keep focus on these apps", `focus` and `swap`
/// skip other apps' windows in every navigation model — the
/// geometric search, scrolling's and monocle's rows, and track's
/// index math — while a lens with the switch off, no lens, and a
/// scroll gesture skip nothing.
@Suite("KiwiVision lens focus keys", .serialized)
@MainActor
struct KiwiVisionLensFocusTests {
    private let member = "test.kiwi.notes"

    /// Windows 1 and 3 are the lens's app, 2 another app's.
    private func makeCore(
        mode: String,
        keepFocus: Bool = true
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-lens-focus-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.eventLoop.ownKeyWindow = { nil }
        for (id, bundle) in [
            (1, member), (2, "test.kiwi.other"), (3, member),
        ] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: 900_031,
                        appName: "App",
                        appBundleID: bundle
                    )
                )
            )
        }
        if mode == "track" {
            core.execute(
                "track.set_new_window",
                args: [.string("own_track")]
            )
        }
        core.execute("set_mode", args: [.string("1"), .string(mode)])
        let lens: [String: JSONValue] = [
            "name": .string("Writing"),
            "apps": .array([.string(member)]),
            "keep_focus": .bool(keepFocus),
        ]
        core.execute("kiwivision.define_lens", args: [.object(lens)])
        return core
    }

    private func focusRight(
        _ core: KiwiCore,
        swapping: Bool = false,
        keyed: Bool = true
    ) -> WindowID? {
        core.state.workspaces.focus(WindowID(1), in: "1")
        _ = core.navigate(
            [.string("right")],
            swapping: swapping,
            keyed: keyed
        )
        return core.activeSpace?.focused
    }

    @Test(
        "focus right skips the other app's window",
        arguments: ["bsp", "scrolling", "monocle", "track"]
    )
    func focusSkips(mode: String) {
        let core = makeCore(mode: mode)
        #expect(focusRight(core) == WindowID(2))
        core.setKiwiVision(.lens("Writing"))
        #expect(focusRight(core) == WindowID(3))
    }

    @Test(
        "swap right skips the other app's window",
        arguments: ["bsp", "scrolling", "monocle", "track"]
    )
    func swapSkips(mode: String) {
        let core = makeCore(mode: mode)
        core.setKiwiVision(.lens("Writing"))
        _ = focusRight(core, swapping: true)
        let order = core.activeSpace?.windows ?? []
        #expect(order.firstIndex(of: WindowID(1)) == 2)
        #expect(order.firstIndex(of: WindowID(3)) == 0)
    }

    @Test("the switch off, plain KiwiVision and a gesture skip nothing")
    func nothingSkipped() {
        let off = makeCore(mode: "scrolling", keepFocus: false)
        off.setKiwiVision(.lens("Writing"))
        #expect(focusRight(off) == WindowID(2))
        let plain = makeCore(mode: "scrolling")
        plain.setKiwiVision(.plain)
        #expect(focusRight(plain) == WindowID(2))
        let gesture = makeCore(mode: "scrolling")
        gesture.setKiwiVision(.lens("Writing"))
        #expect(focusRight(gesture, keyed: false) == WindowID(2))
    }
}
