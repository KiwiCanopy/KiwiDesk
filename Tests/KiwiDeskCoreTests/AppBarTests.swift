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
        global.style = .segments
        global.textColor = "#010203"
        let bar = LayoutAppBar()
        let resolved = bar.resolved(with: global)
        #expect(resolved.thickness == 20)
        #expect(resolved.style == .segments)
        #expect(resolved.textColor == "#010203")
    }

    @Test("Set fields override just themselves")
    func overrideOne() {
        var global = AppBarStyle()
        global.thickness = 20
        global.style = .segments
        var bar = LayoutAppBar()
        bar.thickness = 50
        let resolved = bar.resolved(with: global)
        // The one set field wins; the rest still inherit.
        #expect(resolved.thickness == 50)
        #expect(resolved.style == .segments)
    }

    @Test("Position clamps to the layout's orientation")
    func positionClamp() {
        var scroll = ScrollingParams()
        scroll.appBar.position = .top
        scroll.orientation = .vertical
        // A horizontal edge can't sit on a vertical axis.
        #expect(
            scroll.resolvedBar(global: AppBarStyle()).position
                == .left
        )
        scroll.orientation = .horizontal
        #expect(
            scroll.resolvedBar(global: AppBarStyle()).position
                == .top
        )
    }

    /// Drift guard: every look field must survive a JSON
    /// round-trip on both the global style and a per-layout
    /// override. If a field is ever added to `AppBarStyle` but
    /// missed in `LayoutAppBar` / its Codable / `resolved`, one
    /// of these equalities breaks.
    @Test("Every field round-trips on global and override")
    func fullRoundTrip() throws {
        var settings = TilingSettings()
        settings.appBarStyle = Self.everyGlobalField()
        settings.scrolling.appBar = Self.everyOverrideField()
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

    private static func everyGlobalField() -> AppBarStyle {
        var style = AppBarStyle()
        style.position = .bottom
        style.thickness = 44
        style.style = .segments
        style.activeStyle = .gap
        style.itemSize = 120
        style.itemGap = 3
        style.content = .name
        style.groupAdjacentWindows = false
        style.fontSize = 15
        style.cornerRadius = 5
        style.textColor = "#010101"
        style.boxColor = "#020202"
        style.activeTextColor = "#030303"
        style.activeBoxColor = "#040404"
        style.highlightColor = "#050505"
        style.hoverColor = "#060606"
        style.hoverTextColor = "#070707"
        style.backgroundColor = "#080808"
        style.groupBadgeColor = "#090909"
        style.groupBadgeTextColor = "#0A0A0A"
        return style
    }

    private static func everyOverrideField() -> LayoutAppBar {
        var bar = LayoutAppBar()
        bar.enabled = false
        bar.position = .right
        bar.thickness = 50
        bar.style = .underline
        bar.activeStyle = .highlight
        bar.itemSize = 88
        bar.itemGap = 9
        bar.content = .iconAndName
        bar.groupAdjacentWindows = true
        bar.fontSize = 20
        bar.cornerRadius = 12
        bar.textColor = "#111111"
        bar.boxColor = "#222222"
        bar.activeTextColor = "#333333"
        bar.activeBoxColor = "#444444"
        bar.highlightColor = "#555555"
        bar.hoverColor = "#666666"
        bar.hoverTextColor = "#777777"
        bar.backgroundColor = "#888888"
        bar.groupBadgeColor = "#999999"
        bar.groupBadgeTextColor = "#AAAAAA"
        return bar
    }
}

@Suite("Scrolling app bar geometry")
struct ScrollingBarGeometryTests {
    let layout = ScrollingLayout()

    private func context(
        orientation: ScrollingParams.Orientation = .horizontal,
        barEnabled: Bool = true
    ) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            gaps: .uniform(10)
        )
        context.scrolling.orientation = orientation
        context.scrolling.appBar.enabled = barEnabled
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
        context.scrolling.windowWidth = 300
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

    @Test("Vertical orientation carves a left strip")
    func verticalStrip() throws {
        // A vertical axis resolves the default top edge to the
        // left, so the strip eats window *width*, not height.
        let context = context(orientation: .vertical)
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
                "app_bar.set_style",
                args: [.string("segments")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.appBarStyle.style == .segments
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
                "scroll.set_app_bar_style",
                args: [.string("underline")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.scrolling.appBar.style
                == .underline
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
        core.moveBarItem(from: 0, to: 2)
        #expect(core.activeSpace?.windows == [w2, w3, w1])
    }

    @Test("Invalid global bar values are rejected")
    func globalValidation() {
        let core = makeCore()
        #expect(
            !core.execute(
                "app_bar.set_style",
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
