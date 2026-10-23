import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The desk both suites below share: windows of two apps on Space
/// 1 in a given order and layout, and a "Writing" lens over the
/// member app.
@MainActor
private enum LensNavFixture {
    static let member = "test.kiwi.notes"
    static let other = "test.kiwi.other"

    /// `windows` in Space order: id, bundle id, title. "track"
    /// gives each window its own track, so `right` steps across;
    /// "track-along" one horizontal track, so `right` steps along.
    static func core(
        mode: String,
        windows: [(UInt32, String, String)]
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-lens-nav-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.eventLoop.ownKeyWindow = { nil }
        for (id, bundle, title) in windows {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: 900_031,
                        appName: "App",
                        appBundleID: bundle,
                        title: title
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
        if mode == "track-along" {
            // One horizontal track: `right` steps along it.
            core.execute("track.set_axis", args: [.string("horizontal")])
            core.execute("set_mode", args: [.string("1"), .string("track")])
            return core
        }
        core.execute("set_mode", args: [.string("1"), .string(mode)])
        return core
    }

    /// A "Writing" lens over `member`, its windows by title where
    /// `titles` says so.
    static func defineLens(
        _ core: KiwiCore,
        keepFocus: Bool = true,
        titles: [String]? = nil
    ) {
        var lens: [String: JSONValue] = [
            "name": .string("Writing"),
            "apps": .array([.string(member)]),
            "keep_focus": .bool(keepFocus),
        ]
        if let titles {
            lens["titles"] = .object([
                member: .array(titles.map { .string($0) })
            ])
        }
        core.execute("kiwivision.define_lens", args: [.object(lens)])
    }
}

/// A lens keeps the keys on its apps (#2103 rulings 30, 35, 44):
/// while it is on with "Keep focus on these apps", `focus` and
/// `swap` skip every window the lens keeps hazed in every
/// navigation model — the geometric search and its float tier,
/// scrolling's and monocle's rows, and track's index math — a
/// titled member's unmatched windows included, while a lens with
/// the switch off and plain KiwiVision skip nothing.
@Suite("KiwiVision lens focus keys", .serialized)
@MainActor
struct KiwiVisionLensFocusTests {
    /// Windows 1 and 3 are the lens's app, 2 another app's; 3 is
    /// titled "Mail".
    private func makeCore(
        mode: String,
        keepFocus: Bool = true,
        titles: [String]? = nil
    ) -> KiwiCore {
        let core = LensNavFixture.core(
            mode: mode,
            windows: [
                (1, LensNavFixture.member, ""),
                (2, LensNavFixture.other, ""),
                (3, LensNavFixture.member, "Mail"),
            ]
        )
        LensNavFixture.defineLens(
            core,
            keepFocus: keepFocus,
            titles: titles
        )
        return core
    }

    private func focusRight(
        _ core: KiwiCore,
        swapping: Bool = false
    ) -> WindowID? {
        core.state.workspaces.focus(WindowID(1), in: "1")
        _ = core.navigate([.string("right")], swapping: swapping)
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

    /// Ruling 44: the keys follow the plates, so a member window
    /// the title rule leaves hazed is skipped like a stranger.
    @Test(
        "a titled member's hazed window is skipped",
        arguments: ["bsp", "scrolling", "track"]
    )
    func titledMemberSkips(mode: String) {
        let hazed = makeCore(mode: mode, titles: ["Draft"])
        hazed.setKiwiVision(.lens("Writing"))
        // Window 1's empty title matches nothing either: no
        // window is left to step to.
        #expect(focusRight(hazed) == WindowID(1))
        let clear = makeCore(mode: mode, titles: ["Mail"])
        clear.setKiwiVision(.lens("Writing"))
        #expect(focusRight(clear) == WindowID(3))
    }

    @Test("the switch off and plain KiwiVision skip nothing")
    func nothingSkipped() {
        let off = makeCore(mode: "scrolling", keepFocus: false)
        off.setKiwiVision(.lens("Writing"))
        #expect(focusRight(off) == WindowID(2))
        let plain = makeCore(mode: "scrolling")
        plain.setKiwiVision(.plain)
        #expect(focusRight(plain) == WindowID(2))
    }

    /// The float tier (#488) answers past the tiled edge; it skips
    /// the stranger's float for the member's farther one.
    @Test("the float tier skips the other app's float")
    func floatTierSkips() {
        let core = makeCore(mode: "bsp")
        for (id, x) in [(2, 700.0), (3, 950.0)] {
            core.state.windows.setFloating(WindowID(UInt32(id)), true)
            core.state.apply(
                .windowMoved(
                    WindowID(UInt32(id)),
                    CGRect(x: x, y: 300, width: 200, height: 200)
                )
            )
        }
        #expect(focusRight(core) == WindowID(2))
        core.setKiwiVision(.lens("Writing"))
        #expect(focusRight(core) == WindowID(3))
    }
}

/// A wrap past a row's end asks the lens too (#2103 ruling 35,
/// `wrap_focus` on): it lands on the first member beyond the end,
/// never on a stranger at index 0 and never back on the origin.
@Suite("KiwiVision lens focus keys, wrapping", .serialized)
@MainActor
struct KiwiVisionLensWrapTests {
    /// Space order 2 (stranger), 1, 3 (members), wrap on.
    private func makeCore(mode: String) -> KiwiCore {
        let core = LensNavFixture.core(
            mode: mode,
            windows: [
                (2, LensNavFixture.other, ""),
                (1, LensNavFixture.member, ""),
                (3, LensNavFixture.member, ""),
            ]
        )
        core.execute("set_focus_wrap", args: [.string("this_screen")])
        LensNavFixture.defineLens(core)
        return core
    }

    private func focusRight(
        _ core: KiwiCore,
        from id: UInt32
    ) -> WindowID? {
        core.state.workspaces.focus(WindowID(id), in: "1")
        _ = core.navigate([.string("right")], swapping: false)
        return core.activeSpace?.focused
    }

    @Test(
        "a wrap skips the stranger at the row's start",
        arguments: ["scrolling", "monocle", "track", "track-along"]
    )
    func wrapSkips(mode: String) {
        let core = makeCore(mode: mode)
        #expect(focusRight(core, from: 3) == WindowID(2))
        core.setKiwiVision(.lens("Writing"))
        #expect(focusRight(core, from: 3) == WindowID(1))
    }

    /// With one member window left, a wrap has nowhere to go: the
    /// focus stays rather than wrapping onto itself.
    @Test(
        "a wrap never lands on the origin",
        arguments: ["scrolling", "monocle", "track", "track-along"]
    )
    func wrapNeverSelf(mode: String) {
        let core = makeCore(mode: mode)
        core.state.apply(.windowDestroyed(WindowID(1), wasMinimized: false))
        core.setKiwiVision(.lens("Writing"))
        #expect(focusRight(core, from: 3) == WindowID(3))
        // A step onto the origin would answer `.ok`; one with nowhere
        // to go fails at the dead end.
        core.state.workspaces.focus(WindowID(3), in: "1")
        let step = core.navigate([.string("right")], swapping: false)
        #expect(!step.isSuccess)
    }
}
