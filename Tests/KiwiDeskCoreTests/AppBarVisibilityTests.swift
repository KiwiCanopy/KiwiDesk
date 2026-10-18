import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Each App Bar item carries where its window sits (#2234), judged
/// from the frames the retile issues and the order KiwiDesk
/// intends: the dim reads it, so a lit item is one whose focus
/// moves nothing.
@Suite("App Bar visibility", .serialized)
@MainActor
struct AppBarVisibilityTests {
    private static let bounds = CGRect(
        x: 0,
        y: 0,
        width: 1000,
        height: 800
    )

    private func makeCore(
        mode: String,
        windows: [ManagedWindow]
    ) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-bar-visibility-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in Self.bounds }
        core.execute("set_mode", args: [.string("1"), .string(mode)])
        for window in windows {
            core.state.apply(.windowCreated(window))
        }
        return core
    }

    private func verdicts(
        _ core: KiwiCore
    ) throws -> [WindowID: BarVisibility] {
        let space = try #require(core.activeSpace)
        let app = try #require(
            core.appBarContent(space: space, settings: core.tiler.settings)
        )
        return Dictionary(
            uniqueKeysWithValues: app.items.map { ($0.id, $0.visibility) }
        )
    }

    private func window(_ id: UInt32, floating: Bool = false)
        -> ManagedWindow
    {
        ManagedWindow(
            id: WindowID(id),
            pid: Int32(900_000 + id),
            appName: "App\(id)",
            isFloating: floating
        )
    }

    @Test("Monocle: the focus is visible, the rest hidden")
    func monocleHidesTheRest() throws {
        let core = try makeCore(
            mode: "monocle",
            windows: [window(1), window(2)]
        )
        core.state.apply(.windowFocused(WindowID(1)))
        let seen = try verdicts(core)
        #expect(seen[WindowID(1)] == .visible)
        #expect(seen[WindowID(2)] == .hidden)
    }

    @Test("A float over the focus leaves it partly visible")
    func floatCoversTheTile() throws {
        var float = window(3, floating: true)
        float.frame = CGRect(x: 100, y: 100, width: 300, height: 200)
        let core = try makeCore(
            mode: "monocle",
            windows: [window(1), float]
        )
        core.state.apply(.windowFocused(WindowID(1)))
        let seen = try verdicts(core)
        #expect(seen[WindowID(1)] == .partly(shown: nil))
        #expect(seen[WindowID(3)] == .visible)
    }

    @Test("Scrolling: a column past the edge shows its near side")
    func scrollingCutNamesTheSide() throws {
        let core = try makeCore(
            mode: "scrolling",
            windows: [window(1), window(2), window(3)]
        )
        core.execute("scroll.set_slot_size", args: [.number(700)])
        core.state.apply(.windowFocused(WindowID(1)))
        let seen = try verdicts(core)
        #expect(seen[WindowID(1)] == .visible)
        #expect(seen[WindowID(2)] == .partly(shown: .left))
    }

    /// The held member — what the layout put in front, read off
    /// a retile — stays on top while a float holds the focus, not
    /// the row's first.
    @Test("Monocle with a float focused keeps its held member")
    func monocleFloatFocusKeepsTheHold() throws {
        var float = window(3, floating: true)
        float.frame = CGRect(x: 100, y: 100, width: 300, height: 200)
        let core = try makeCore(
            mode: "monocle",
            windows: [window(1), window(2), float]
        )
        core.state.apply(.windowFocused(WindowID(2)))
        core.retile()
        core.state.apply(.windowFocused(WindowID(3)))
        let seen = try verdicts(core)
        #expect(seen[WindowID(1)] == .hidden)
        #expect(seen[WindowID(2)] == .partly(shown: nil))
    }

    /// The box is what the layout fills: a float reaching into the
    /// App Bar's reserved strip is not wholly shown.
    @Test("A float under the reserved strip is partly visible")
    func floatUnderTheStripIsPartly() throws {
        var float = window(3, floating: true)
        float.frame = CGRect(x: 100, y: 0, width: 300, height: 200)
        let core = try makeCore(
            mode: "monocle",
            windows: [window(1), float]
        )
        let space = try #require(core.activeSpace)
        let screen = try #require(
            TilingEngine.screen(for: space.id, in: core.state)
        )
        try #require(core.tiler.layoutBounds(on: screen, for: space).minY > 0)
        let seen = try verdicts(core)
        #expect(seen[WindowID(3)] == .partly(shown: .bottom))
    }

    /// A parked member is hidden. The park leaves a 1 pt peek
    /// inside the region it used, which the judge's cut tolerance
    /// already reads as hidden; the stash test beside it is a net
    /// for a wider peek, which this fixture cannot reach.
    @Test("Monocle park hides the parked members")
    func monocleParkHides() throws {
        let core = try makeCore(
            mode: "monocle",
            windows: [window(1), window(2)]
        )
        core.execute("monocle.set_hide_style", args: [.string("park")])
        core.state.apply(.windowFocused(WindowID(1)))
        let seen = try verdicts(core)
        #expect(seen[WindowID(1)] == .visible)
        #expect(seen[WindowID(2)] == .hidden)
    }

    @Test("A float's own move refreshes the bars")
    func floatMoveRefreshesTheBars() throws {
        var float = window(3, floating: true)
        float.frame = CGRect(x: 100, y: 100, width: 300, height: 200)
        let core = try makeCore(
            mode: "monocle",
            windows: [window(1), float]
        )
        #expect(core.appBarListsShownFloat(WindowID(3)))
        #expect(!core.appBarListsShownFloat(WindowID(1)))
        core.handleFloatGeometryForBars(WindowID(1))
        #expect(core.deferred.task(for: .barVisibilityRefresh) == nil)
        // Through the event arms, not only the door.
        let moved = CGRect(x: 300, y: 300, width: 300, height: 200)
        core.handle(.windowMoved(WindowID(3), moved))
        #expect(core.deferred.task(for: .barVisibilityRefresh) != nil)
        core.deferred.cancel(.barVisibilityRefresh)
        core.handle(.windowResized(WindowID(3), moved))
        #expect(core.deferred.task(for: .barVisibilityRefresh) != nil)
    }
}
