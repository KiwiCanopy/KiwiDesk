import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

@Suite("App bar override resolution")
struct AppBarOverrideTests {
    @Test("Unset fields inherit the global style")
    func inheritance() {
        var global = AppBarStyle()
        global.thickness = 20
        global.tabBackground = .plain
        global.textColor = "#010203"
        let bar = LayoutAppBar()
        let resolved = bar.resolved(with: global)
        #expect(resolved.thickness == 20)
        #expect(resolved.tabBackground == .plain)
        #expect(resolved.textColor == "#010203")
    }

    @Test("Set fields override just themselves")
    func overrideOne() {
        var global = AppBarStyle()
        global.thickness = 20
        global.tabBackground = .plain
        var bar = LayoutAppBar()
        bar.thickness = 50
        let resolved = bar.resolved(with: global)
        // The one set field wins; the rest still inherit.
        #expect(resolved.thickness == 50)
        #expect(resolved.tabBackground == .plain)
    }

    @Test("Stored edge is absolute; override beats global")
    func edgeResolves() {
        var scroll = ScrollingParams()
        // No override: the global edge wins, orientation is
        // irrelevant (#293 — the edge is stored absolute).
        var global = AppBarStyle()
        global.edge = .bottom
        scroll.orientation = .vertical
        #expect(
            scroll.resolvedBar(global: global).edge == .bottom
        )
        // A per-layout override beats the global on any axis.
        scroll.appBar.edge = .right
        #expect(
            scroll.resolvedBar(global: global).edge == .right
        )
        scroll.orientation = .horizontal
        #expect(
            scroll.resolvedBar(global: global).edge == .right
        )
    }

    /// Drift guard: every look field must survive a JSON
    /// round-trip on both the global style and a per-layout
    /// override. If a field is ever added to `AppBarStyle` but
    /// missed in `LayoutAppBar` / its Codable / `resolved`, one
    /// of these equalities breaks. The fixtures (shared with
    /// `AppBarParityTests`) are pinned exhaustive there, so a new
    /// field can't slip past this round-trip unset.
    @Test("Every field round-trips on global and override")
    func fullRoundTrip() throws {
        var settings = TilingSettings()
        settings.appBarStyle = AppBarFixtures.everyGlobalField()
        settings.scrolling.appBar =
            AppBarFixtures.everyOverrideField()
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded.appBarStyle == settings.appBarStyle)
        #expect(
            decoded.scrolling.appBar == settings.scrolling.appBar
        )
    }
}

@Suite("Scrolling app bar geometry")
struct ScrollingBarGeometryTests {
    let layout = ScrollingLayout()

    private func context(
        orientation: ScrollingParams.Orientation = .horizontal,
        barEnabled: Bool = true,
        edge: AppBarEdge = .top
    ) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            gaps: .uniform(10)
        )
        context.scrolling.orientation = orientation
        context.scrolling.appBar.enabled = barEnabled
        context.scrolling.appBar.edge = edge
        return context
    }

    @Test("Horizontal bar carves a top strip by default")
    func horizontalStrip() throws {
        let context = context()
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        let usable = context.usable
        let window = try #require(frames[w1])
        // Default 32pt top strip + one 10pt inner gap.
        #expect(window.minY == usable.minY + 32 + 10)
        #expect(window.height == usable.height - 32 - 10)
        #expect(window.width == usable.width)
    }

    @Test("Vertical orientation stacks windows into rows")
    func verticalRows() throws {
        var context = context(
            orientation: .vertical,
            barEnabled: false
        )
        context.scrolling.slotSize = .points(300)
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let first = try #require(frames[w1])
        let second = try #require(frames[w2])
        // Rows: full width, fixed height, stacked down the y.
        #expect(first.width == context.usable.width)
        #expect(first.height == 300)
        #expect(second.minY > first.minY)
        #expect(first.minX == context.usable.minX)
    }

    @Test("A left edge carves a left strip")
    func verticalStrip() throws {
        // The edge is absolute (#293): a left bar eats window
        // *width*, not height, on any orientation.
        let context = context(orientation: .vertical, edge: .left)
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        let usable = context.usable
        let window = try #require(frames[w1])
        #expect(window.minX == usable.minX + 32 + 10)
        #expect(window.width == usable.width - 32 - 10)
        #expect(window.height == usable.height)
    }

    @Test("A disabled bar leaves the full usable area")
    func disabledBar() throws {
        let context = context(barEnabled: false)
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        #expect(frames[w1] == context.usable)
    }
}

@Suite("App bar commands", .serialized)
@MainActor
struct AppBarCommandTests {
    @Test("Global app_bar.set_* writes the shared style")
    func globalStyle() {
        let core = makeCore()
        #expect(
            core.execute(
                "app_bar.set_thickness",
                args: [.number(40)]
            ).isSuccess
        )
        #expect(core.tiler.settings.appBarStyle.thickness == 40)
        #expect(
            core.execute(
                "app_bar.set_tab_background",
                args: [.string("plain")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.appBarStyle.tabBackground
                == .plain
        )
    }

    @Test("scroll.set_app_bar_* writes a scrolling override")
    func scrollOverride() {
        let core = makeCore()
        #expect(
            core.execute(
                "scroll.set_orientation",
                args: [.string("vertical")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.scrolling.orientation
                == .vertical
        )
        #expect(
            core.execute(
                "scroll.set_app_bar_tab_background",
                args: [.string("plain")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.scrolling.appBar.tabBackground
                == .plain
        )
        // Untouched fields stay nil (inherit the global look).
        #expect(
            core.tiler.settings.scrolling.appBar.thickness
                == nil
        )
    }

    @Test("The scrolling app bar lists the space's windows")
    func scrollingBarItems() throws {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        for (index, name) in ["A", "B", "C"].enumerated() {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index + 1)),
                        pid: 1,
                        appName: name
                    )
                )
            )
        }
        let space = try #require(core.activeSpace)
        #expect(
            core.barGroups(in: space, grouping: true).count == 3
        )
    }

    @Test("Dragging a scrolling item reorders the windows")
    func scrollingReorder() throws {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        for (index, name) in ["A", "B", "C"].enumerated() {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index + 1)),
                        pid: 1,
                        appName: name
                    )
                )
            )
        }
        core.moveBarItem(space: SpaceID(1), from: 0, to: 2)
        #expect(core.activeSpace?.windows == [w2, w3, w1])
    }

    @Test("Invalid global bar values are rejected")
    func globalValidation() {
        let core = makeCore()
        #expect(
            !core.execute(
                "app_bar.set_tab_background",
                args: [.string("triangles")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "app_bar.set_thickness",
                args: [.string("thick")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "app_bar.set_nonsense",
                args: [.number(1)]
            ).isSuccess
        )
    }
}
