import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
}

/// The app bar's window groups for a space, resolving the
/// grouping flag the way the live bar does (monocle override
/// over the global style).
@MainActor
private func groups(
    _ core: KiwiCore,
    in space: Space
) -> [[WindowID]] {
    core.barGroups(
        in: space,
        grouping: core.tiler.settings.monocle
            .resolvedBar(global: core.tiler.settings.appBarStyle)
            .style.groupAdjacentWindows
    )
}

private func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
    monocle: (inout MonocleParams) -> Void = { _ in }
) -> LayoutContext {
    var context = LayoutContext(
        bounds: bounds,
        gaps: .uniform(10)
    )
    monocle(&context.monocle)
    return context
}

@Suite("Monocle bar geometry")
struct MonocleGeometryTests {
    let layout = MonocleLayout()

    @Test("Bar disabled: every window fills the usable area")
    func barDisabled() throws {
        let context = makeContext { $0.appBar.enabled = false }
        let frames = layout.calculateGeometry(
            for: ids(3),
            in: context
        )
        for id in ids(3) {
            #expect(frames[id] == context.usable)
        }
    }

    @Test(
        "Bar strip and window never overlap and stay usable",
        arguments: [
            AppBarEdge.top, .bottom, .left, .right,
        ]
    )
    func stripCarving(edge: AppBarEdge) throws {
        // The edge is stored absolute (#293) — set it directly.
        let context = makeContext {
            $0.appBar.edge = edge
        }
        let usable = context.usable
        let bar = try #require(
            context.monocle.barFrame(in: usable, global: AppBarStyle())
        )
        let frames = layout.calculateGeometry(
            for: ids(2),
            in: context
        )
        let window = try #require(frames[w1])
        // All windows share the same frame.
        #expect(frames[w2] == window)
        // Both stay inside the usable area (no monitor bleed).
        #expect(usable.contains(bar))
        #expect(usable.contains(window))
        // The strip and the window never overlap.
        #expect(!bar.intersects(window))
        // The strip sits on the resolved edge.
        switch edge {
        case .top: #expect(bar.minY == usable.minY)
        case .bottom: #expect(bar.maxY == usable.maxY)
        case .left: #expect(bar.minX == usable.minX)
        case .right: #expect(bar.maxX == usable.maxX)
        }
        // One inner gap between strip and window.
        #expect(bar.height == 32 || bar.width == 32)
        if edge == .top {
            #expect(window.minY == bar.maxY + 10)
        }
    }

    @Test("Stored edge resolves absolute, override beats global")
    func edgeResolves() {
        var params = MonocleParams()
        // No override: the global edge wins.
        var global = AppBarStyle()
        global.edge = .right
        #expect(
            params.resolvedBar(global: global).edge == .right
        )
        // A per-layout override beats the global.
        params.appBar.edge = .left
        #expect(
            params.resolvedBar(global: global).edge == .left
        )
        // Orientation no longer affects the edge (#293).
        params.orientation = .horizontal
        #expect(
            params.resolvedBar(global: global).edge == .left
        )
    }

    @Test("Oversized thickness never produces negative frames")
    func oversizedThickness() throws {
        let context = makeContext {
            $0.appBar.thickness = 5000
        }
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        let window = try #require(frames[w1])
        #expect(window.width >= 0)
        #expect(window.height >= 0)
        let bar = try #require(
            context.monocle.barFrame(in: context.usable, global: AppBarStyle())
        )
        #expect(context.usable.contains(bar))
    }
}

@Suite("Monocle settings")
struct MonocleSettingsTests {
    @Test("Settings survive a profile JSON round-trip")
    func codableRoundTrip() throws {
        var settings = TilingSettings()
        settings.monocle.orientation = .vertical
        settings.monocle.appBar.enabled = false
        settings.monocle.appBar.edge = .bottom
        settings.monocle.appBar.thickness = 48
        settings.monocle.appBar.tabBackground = .plain
        settings.monocle.appBar.activeIndicator = .gap
        settings.monocle.appBar.itemSize = 90
        settings.monocle.appBar.itemGap = 0
        settings.monocle.appBar.content = .icon
        settings.monocle.appBar.highlightColor = "#FF0000"
        settings.monocle.appBar.groupAdjacentWindows = false
        settings.monocle.appBar.groupBadgeColor = "#112233"
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded.monocle == settings.monocle)
    }

    @Test("Global style and per-layout overrides split in JSON")
    func nestedBarKey() throws {
        let data = try JSONEncoder().encode(TilingSettings())
        let json = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        // The global look sits top-level; item_size is a
        // concrete field there.
        let global = try #require(
            json["app_bar"] as? [String: Any]
        )
        #expect(global["item_size"] as? Double == 0)
        // The per-layout bar under monocle only carries its
        // own enabled flag until a field is overridden.
        let layout = try #require(
            json["layout"] as? [String: Any]
        )
        let monocle = try #require(
            layout["monocle"] as? [String: Any]
        )
        let bar = try #require(
            monocle["app_bar"] as? [String: Any]
        )
        #expect(bar["enabled"] as? Bool == true)
        #expect(bar["item_size"] == nil)
    }

    @Test("Profiles without a monocle key keep the defaults")
    func lenientDecoding() throws {
        let json = #"{"layout": {"monocle": {}}}"#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(decoded.monocle == MonocleParams())
        #expect(decoded.monocle.appBar.enabled)
        // Nothing is overridden, so every look field inherits.
        #expect(decoded.monocle.appBar.itemSize == nil)
        #expect(decoded.monocle.orientation == .horizontal)
    }

    @Test("Partial bar objects override only the listed fields")
    func lenientBarDecoding() throws {
        let json = #"""
            {"layout": {"monocle": {
                "app_bar": {"item_size": 90}
            }}}
            """#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(decoded.monocle.appBar.itemSize == 90)
        // Unlisted fields stay nil (inherit the global style).
        #expect(decoded.monocle.appBar.thickness == nil)
        #expect(decoded.monocle.appBar.enabled)
    }
}

@Suite("App bar math")
struct AppBarMathTests {
    @Test("item_size 0 uses the measured auto width, clamped")
    func autoSlot() {
        // The measured auto width passes through when sane.
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 0,
                content: .iconAndName,
                thickness: 32,
                axis: 1000,
                autoWidth: 88
            ) == 88
        )
        // Clamped up to the icon minimum when the measurement is
        // tiny (icons never clip).
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 0,
                content: .iconAndName,
                thickness: 32,
                axis: 1000,
                autoWidth: 10
            ) == 32
        )
        // Clamped down to a quarter of the bar when it's huge.
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 0,
                content: .name,
                thickness: 32,
                axis: 1000,
                autoWidth: 900
            ) == 250
        )
    }

    @MainActor
    @Test("Auto width measures horizontally, standard vertically")
    func autoWidthMeasures() {
        let short = [item("Hi")]
        let long = [item("A Much Longer Window Title")]
        let style = AppBarStyle()
        let shortW = AppBarOverlay.autoSlotWidth(
            items: short,
            style: style,
            horizontal: true,
            thickness: 32
        )
        let longW = AppBarOverlay.autoSlotWidth(
            items: long,
            style: style,
            horizontal: true,
            thickness: 32
        )
        // A longer name yields a wider slot; measured, not fixed.
        #expect(longW > shortW)
        // Vertical bars fall back to a content standard.
        #expect(
            AppBarOverlay.autoSlotWidth(
                items: long,
                style: style,
                horizontal: false,
                thickness: 32
            ) == AppBarOverlay.standardIconAndNameLength
        )
    }

    private func item(_ name: String) -> AppBarOverlay.Item {
        AppBarOverlay.Item(id: WindowID(1), name: name, icon: nil)
    }

    @Test("Explicit item_size wins, clamped on both sides")
    func explicitSlot() {
        // The user's size as-is while it is sane.
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 80,
                content: .iconAndName,
                thickness: 32,
                axis: 1000,
                autoWidth: 140
            ) == 80
        )
        // Too small: icons must survive — at least the
        // icon square.
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 10,
                content: .iconAndName,
                thickness: 32,
                axis: 1000,
                autoWidth: 140
            ) == 32
        )
        // Too big: capped at a quarter of the bar.
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 900,
                content: .iconAndName,
                thickness: 32,
                axis: 1000,
                autoWidth: 140
            ) == 250
        )
        // Tiny bar: the icon minimum beats the quarter cap.
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 80,
                content: .iconAndName,
                thickness: 32,
                axis: 60,
                autoWidth: 140
            ) == 32
        )
    }

    @Test("Scroll offset follows the active item into view")
    func scrollFollowsFocus() {
        // 10 items of 100 (no gaps) in a 320 strip. Focusing
        // the last item scrolls all the way to the end — the
        // margin would ask for 696 but the clamp at
        // total - axis (680) wins; there is nothing beyond
        // the last item to keep clear of.
        #expect(
            AppBarOverlay.scrollOffset(
                current: 0,
                activeIndex: 9,
                slot: 100,
                gap: 0,
                count: 10,
                axis: 320,
                margin: 16
            ) == 680
        )
        // A middle item does keep the margin: item 5 must end
        // 16pt clear of the right edge -> 600 - 320 + 16.
        #expect(
            AppBarOverlay.scrollOffset(
                current: 0,
                activeIndex: 5,
                slot: 100,
                gap: 0,
                count: 10,
                axis: 320,
                margin: 16
            ) == 296
        )
        // Scrolling back to the first item pins at 0 — the
        // margin never pushes the offset negative.
        #expect(
            AppBarOverlay.scrollOffset(
                current: 696,
                activeIndex: 0,
                slot: 100,
                gap: 0,
                count: 10,
                axis: 320,
                margin: 16
            ) == 0
        )
        // An already-visible active item moves nothing.
        #expect(
            AppBarOverlay.scrollOffset(
                current: 100,
                activeIndex: 2,
                slot: 100,
                gap: 0,
                count: 10,
                axis: 320,
                margin: 16
            ) == 100
        )
    }

    @Test("Scroll offset clamps, and is 0 while items fit")
    func scrollClamps() {
        // Nil active index (manual arrow scroll): only clamp.
        #expect(
            AppBarOverlay.scrollOffset(
                current: 9999,
                activeIndex: nil,
                slot: 100,
                gap: 0,
                count: 10,
                axis: 320,
                margin: 16
            ) == 680
        )
        #expect(
            AppBarOverlay.scrollOffset(
                current: -50,
                activeIndex: nil,
                slot: 100,
                gap: 0,
                count: 10,
                axis: 320,
                margin: 16
            ) == 0
        )
        // Everything fits: no scrolling, whatever the state.
        #expect(
            AppBarOverlay.scrollOffset(
                current: 300,
                activeIndex: 1,
                slot: 100,
                gap: 0,
                count: 3,
                axis: 320,
                margin: 16
            ) == 0
        )
    }

    @Test("Drop index maps a drag position to its slot")
    func dropIndex() {
        // Slots of 100pt, 10pt apart, starting at 0.
        #expect(
            AppBarOverlay.dropIndex(
                center: 50,
                start: 0,
                slot: 100,
                gap: 10,
                count: 3
            ) == 0
        )
        #expect(
            AppBarOverlay.dropIndex(
                center: 165,
                start: 0,
                slot: 100,
                gap: 10,
                count: 3
            ) == 1
        )
        // Past the ends: clamped into the item range.
        #expect(
            AppBarOverlay.dropIndex(
                center: -40,
                start: 0,
                slot: 100,
                gap: 10,
                count: 3
            ) == 0
        )
        #expect(
            AppBarOverlay.dropIndex(
                center: 900,
                start: 0,
                slot: 100,
                gap: 10,
                count: 3
            ) == 2
        )
        // A centered / scrolled group shifts the mapping.
        #expect(
            AppBarOverlay.dropIndex(
                center: 60,
                start: 55,
                slot: 100,
                gap: 10,
                count: 3
            ) == 0
        )
    }

    @Test("Overflowing frames start at the scroll offset")
    func scrolledFrames() {
        let frames = AppBarOverlay.frames(
            lengths: Array(repeating: 100, count: 10),
            in: CGRect(x: 0, y: 0, width: 320, height: 32),
            gap: 0,
            horizontal: true,
            scrolledBy: 250
        )
        #expect(frames[0].minX == -250)
        #expect(frames[3].minX == 50)
    }

    @Test("Icon bars refuse slots smaller than the icon square")
    func iconMinimum() {
        #expect(
            AppBarOverlay.minimumSlot(
                thickness: 32,
                content: .iconAndName
            ) == 32
        )
        #expect(
            AppBarOverlay.minimumSlot(
                thickness: 32,
                content: .icon
            ) == 32
        )
        // Text-only bars keep just a sliver of legibility.
        #expect(
            AppBarOverlay.minimumSlot(
                thickness: 32,
                content: .name
            ) < 32
        )
    }

    @Test("Frames line up along the axis, centered as a group")
    func framesCentered() {
        let frames = AppBarOverlay.frames(
            lengths: [100, 100],
            in: CGRect(x: 0, y: 0, width: 320, height: 32),
            gap: 10,
            horizontal: true
        )
        // 210 used of 320: the group starts at 55.
        #expect(frames[0].minX == 55)
        #expect(frames[1].minX == 165)
        #expect(frames[0].height == 32)
        // Vertical bars stack top-down instead.
        let vertical = AppBarOverlay.frames(
            lengths: [40, 40],
            in: CGRect(x: 0, y: 0, width: 32, height: 100),
            gap: 0,
            horizontal: false
        )
        #expect(vertical[0].minY == 10)
        #expect(vertical[1].minY == 50)
        #expect(vertical[1].width == 32)
    }

    @Test("Auto font size scales with thickness, clamped")
    func autoFontSize() {
        let slim = AppBarItemView.autoFontSize(
            forThickness: 20
        )
        let fat = AppBarItemView.autoFontSize(
            forThickness: 48
        )
        #expect(slim < fat)
        // Extremes stay readable and inside the strip.
        #expect(
            AppBarItemView.autoFontSize(
                forThickness: 4
            ) == 9
        )
        #expect(
            AppBarItemView.autoFontSize(
                forThickness: 400
            ) == 28
        )
    }

    @Test("Stacked names truncate to the lines that fit")
    func stackedText() {
        #expect(
            AppBarItemView.stacked("Safari", limit: 10)
                == "S\na\nf\na\nr\ni"
        )
        #expect(
            AppBarItemView.stacked("Safari", limit: 4)
                == "S\na\nf\n…"
        )
        #expect(
            AppBarItemView.stacked("Safari", limit: 0)
                .isEmpty
        )
    }
}

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

@Suite("Monocle commands", .serialized)
@MainActor
struct MonocleCommandTests {
    @Test("monocle.* setters update the settings")
    func setters() {
        let core = makeCore()
        #expect(
            core.execute(
                "monocle.set_orientation",
                args: [.string("vertical")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.orientation
                == .vertical
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_tab_background",
                args: [.string("plain")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.appBar.tabBackground
                == .plain
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_active_indicator",
                args: [.string("gap")]
            ).isSuccess
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_content",
                args: [.string("icon_and_name")]
            ).isSuccess
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_item_size",
                args: [.number(150)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.appBar.itemSize == 150
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_highlight_color",
                args: [.string("#123456")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.appBar.highlightColor
                == "#123456"
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_hover_color",
                args: [.string("#4E9F3D40")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.appBar.hoverColor
                == "#4E9F3D40"
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_hover_text_color",
                args: [.string("#101010")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.appBar.hoverTextColor
                == "#101010"
        )
    }

    @Test("Hover default is a shade off the highlight")
    func hoverDefault() {
        let bar = AppBarStyle()
        #expect(bar.hoverColor != bar.highlightColor)
    }

    @Test("Invalid values are rejected")
    func validation() {
        let core = makeCore()
        #expect(
            !core.execute(
                "monocle.set_orientation",
                args: [.string("diagonal")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "monocle.set_app_bar_edge",
                args: [.string("middle")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "monocle.set_app_bar_item_size",
                args: [.string("wide")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "monocle.set_app_bar_text_color",
                args: [.string("red")]
            ).isSuccess
        )
    }

    @Test("Edge takes the four edges, rejects start/end")
    func edgeTokens() {
        let core = makeCore()
        // Absolute tokens are stored as-is (#293) — the layout
        // orientation plays no part.
        #expect(
            core.execute(
                "monocle.set_app_bar_edge",
                args: [.string("left")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle
                .resolvedBar(global: AppBarStyle()).edge == .left
        )
        // The old axis-relative tokens are no longer valid.
        #expect(
            !core.execute(
                "monocle.set_app_bar_edge",
                args: [.string("start")]
            ).isSuccess
        )
    }
}

@Suite("Monocle grouping & reorder", .serialized)
@MainActor
struct MonocleGroupingTests {
    /// A monocle space with one window per name, ids 1...n.
    private func makeNamedCore(
        _ names: [String]
    ) -> KiwiCore {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        for (index, name) in names.enumerated() {
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
        return core
    }

    @Test("Only adjacent same-app windows group")
    func adjacentOnly() throws {
        #expect(
            KiwiCore.adjacentRuns(
                of: ["Zed", "Zed", "Finder", "Zed"]
            ) == [0..<2, 2..<3, 3..<4]
        )
        #expect(KiwiCore.adjacentRuns(of: []).isEmpty)
        let core = makeNamedCore(
            ["Zed", "Zed", "Finder", "Zed"]
        )
        let space = try #require(core.activeSpace)
        #expect(
            groups(core, in: space) == [
                [w1, w2], [w3], [WindowID(4)],
            ]
        )
    }

    @Test("Focus inside a group expands it into single items")
    func expansion() throws {
        let core = makeNamedCore(["Zed", "Zed", "Finder"])
        core.state.workspaces.focus(w1, in: SpaceID(1))
        let space = try #require(core.activeSpace)
        #expect(
            groups(core, in: space) == [
                [w1], [w2], [w3],
            ]
        )
        // Focus leaving the group collapses it again.
        core.state.workspaces.focus(w3, in: SpaceID(1))
        let after = try #require(core.activeSpace)
        #expect(
            groups(core, in: after) == [[w1, w2], [w3]]
        )
    }

    @Test("group_adjacent_windows off: one item per window")
    func groupingOff() throws {
        let core = makeNamedCore(["Zed", "Zed"])
        #expect(
            core.execute(
                "monocle.set_app_bar_group_adjacent_windows",
                args: [.bool(false)]
            ).isSuccess
        )
        let space = try #require(core.activeSpace)
        #expect(
            groups(core, in: space) == [[w1], [w2]]
        )
    }

    @Test("Dragging an item reorders the window array")
    func moveSingle() {
        let core = makeNamedCore(["A", "B", "C"])
        core.moveBarItem(space: SpaceID(1), from: 0, to: 2)
        #expect(core.activeSpace?.windows == [w2, w3, w1])
        // Out-of-range moves are ignored.
        core.moveBarItem(space: SpaceID(1), from: 0, to: 9)
        #expect(core.activeSpace?.windows == [w2, w3, w1])
    }

    @Test("Dragging a group moves all its members together")
    func moveGroup() {
        let core = makeNamedCore(["Zed", "Zed", "Finder"])
        // Items: [Zed ×2] [Finder] — swap their slots.
        core.moveBarItem(space: SpaceID(1), from: 0, to: 1)
        #expect(core.activeSpace?.windows == [w3, w1, w2])
    }
}

@Suite("Monocle focus cycling", .serialized)
@MainActor
struct MonocleCycleTests {
    /// Three tiled windows in a monocle space, w1 focused.
    private func makeMonocleCore() -> KiwiCore {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: 1,
                        appName: "App\(id)"
                    )
                )
            )
        }
        core.state.workspaces.focus(w1, in: SpaceID(1))
        return core
    }

    @Test("focus cycles the orientation axis, wraps when on")
    func cycleAndWrap() {
        let core = makeMonocleCore()
        // Wrap is opt-in (#257: off by default like the other
        // array-order layouts), so turn it on to exercise it.
        core.execute(
            "monocle.set_wrap_focus",
            args: [.bool(true)]
        )
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == w2)
        core.execute("focus", args: [.string("right")])
        #expect(core.activeSpace?.focused == w3)
        // Wrap: past the last window back to the first.
        core.execute("focus", args: [.string("right")])
        #expect(core.activeSpace?.focused == w1)
        // And backwards off the front to the last.
        core.execute("focus", args: [.string("left")])
        #expect(core.activeSpace?.focused == w3)
    }

    @Test("Cross-axis directions fall through to geometry")
    func crossAxisFallsThrough() {
        let core = makeMonocleCore()
        // Horizontal orientation: up/down are not intercepted,
        // and all monocle frames coincide, so there is no
        // window above — the geometric path reports that.
        let response = core.execute(
            "focus",
            args: [.string("up")]
        )
        #expect(!response.isSuccess)
        #expect(core.activeSpace?.focused == w1)
    }

    @Test("Vertical orientation cycles on up/down instead")
    func verticalAxis() {
        let core = makeMonocleCore()
        core.execute(
            "monocle.set_orientation",
            args: [.string("vertical")]
        )
        core.execute("focus", args: [.string("down")])
        #expect(core.activeSpace?.focused == w2)
        core.execute("focus", args: [.string("up")])
        #expect(core.activeSpace?.focused == w1)
        // Left/right now fall through to the geometric path.
        #expect(
            !core.execute("focus", args: [.string("right")])
                .isSuccess
        )
    }

    @Test("swap reorders the sequence but never wraps")
    func swapReorders() {
        let core = makeMonocleCore()
        #expect(
            core.execute("swap", args: [.string("right")])
                .isSuccess
        )
        #expect(
            core.activeSpace?.windows == [w2, w1, w3]
        )
        // swap never wraps (#168): from the first slot, left is a
        // no-op — a wrapping swap would teleport the window end to
        // end. focus wrapping is a separate, opt-out toggle.
        core.state.workspaces.focus(w2, in: SpaceID(1))
        #expect(
            !core.execute("swap", args: [.string("left")])
                .isSuccess
        )
        #expect(
            core.activeSpace?.windows == [w2, w1, w3]
        )
    }

    @Test("A single window cycles onto itself as a no-op")
    func singleWindow() {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w1, pid: 1, appName: "A")
            )
        )
        core.state.workspaces.focus(w1, in: SpaceID(1))
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == w1)
    }
}
