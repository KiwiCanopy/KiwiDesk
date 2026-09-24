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
    return makeTestCore(configDirectory: directory)
}

@Suite("App bar override resolution")
struct AppBarOverrideTests {
    @Test("Unset fields inherit the global style")
    func inheritance() {
        var global = AppBarStyle()
        global.content = .icon
        global.titleCap = 7
        let resolved = LayoutAppBar().resolved(with: global)
        #expect(resolved.content == .icon)
        #expect(resolved.titleCap == 7)
    }

    @Test("Set fields override just themselves")
    func overrideOne() {
        var global = AppBarStyle()
        global.content = .icon
        global.titleCap = 7
        var bar = LayoutAppBar()
        bar.content = .title
        let resolved = bar.resolved(with: global)
        // The one set field wins; the rest still inherit.
        #expect(resolved.content == .title)
        #expect(resolved.titleCap == 7)
    }

    @Test("The shelf's edge is absolute, orientation aside")
    func edgeResolves() {
        var scroll = ScrollingParams()
        // No override: the global edge wins, orientation is
        // irrelevant (#293 — the edge is stored absolute).
        var global = AppBarLook()
        global.edge = .bottom
        scroll.orientation = .vertical
        #expect(
            scroll.resolvedBar(global: global).edge == .bottom
        )
        scroll.orientation = .horizontal
        #expect(
            scroll.resolvedBar(global: global).edge == .bottom
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

    /// The shelf reserves the bar's room before the layout runs
    /// (#1517), so the layout places the same frames with the
    /// App Bar on or off, on either axis.
    @Test(
        "The App Bar's switch moves no window",
        arguments: [
            ScrollingParams.Orientation.horizontal, .vertical,
        ]
    )
    func barSwitchMovesNothing(
        orientation: ScrollingParams.Orientation
    ) throws {
        var on = context(orientation: orientation)
        var off = context(orientation: orientation, barEnabled: false)
        on.scrolling.slotSize = .points(300)
        off.scrolling.slotSize = .points(300)
        let shown = layout.calculateGeometry(for: [w1, w2], in: on)
        let hidden = layout.calculateGeometry(for: [w1, w2], in: off)
        #expect(shown == hidden)
        let first = try #require(shown[w1])
        #expect(first.minX == on.usable.minX)
        #expect(first.minY == on.usable.minY)
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
}

@Suite("App bar commands", .serialized)
@MainActor
struct AppBarCommandTests {
    @Test("Global app_bar.set_* writes the shared style")
    func globalStyle() {
        let core = makeCore()
        #expect(
            core.execute(
                "kiwishelf.set_thickness",
                args: [.number(44)]
            ).isSuccess
        )
        #expect(core.tiler.settings.kiwishelf.thickness == 44)
        #expect(
            core.execute(
                "kiwishelf.set_background_style",
                args: [.string("plain")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.kiwishelf.backgroundStyle
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
                "scroll.set_app_bar_content",
                args: [.string("icon")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.scrolling.appBar.content == .icon
        )
        // Untouched fields stay nil (inherit the global look).
        #expect(
            core.tiler.settings.scrolling.appBar.titleCap == nil
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
                "kiwishelf.set_background_style",
                args: [.string("triangles")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "kiwishelf.set_thickness",
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
