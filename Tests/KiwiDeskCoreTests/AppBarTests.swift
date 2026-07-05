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
}
