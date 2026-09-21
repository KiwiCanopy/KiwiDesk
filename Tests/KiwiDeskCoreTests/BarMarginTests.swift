import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// One placement rule for both bars (#1516): from the screen
/// edge inwards, the bar's OUTER margin (absolute; 0 is flush),
/// the strip, the bar's INNER margin, then the windows' own
/// outer gap — which alone keeps the focus ring's room, so the
/// inner margin is extra and needs no floor. Both strips are cut
/// from the raw visible bounds; on a shared edge the Space Bar is
/// carved first and each bar owns its margins, so between them
/// the two add.
@Suite("Bar margins")
struct BarMarginTests {
    // Pinned (#531): every number below reasons from it.
    private let visible = CGRect(
        x: 0,
        y: 25,
        width: 1920,
        height: 1055
    )

    private func spaceBar(
        edge: AppBarEdge,
        outer: CGFloat,
        inner: CGFloat
    ) -> SpaceBarStyle {
        var style = SpaceBarStyle()
        style.edge = edge
        // Pinned (#660): the sums below reason from it.
        style.thickness = 32
        style.outerMargin = outer
        style.innerMargin = inner
        return style
    }

    private func context(
        bounds: CGRect,
        gaps: Gaps,
        edge: AppBarEdge,
        outer: CGFloat = 0,
        inner: CGFloat = 0
    ) -> LayoutContext {
        var context = LayoutContext(bounds: bounds, gaps: gaps)
        // Pinned (#660): the sums below reason from it.
        context.appBarStyle.thickness = 32
        context.appBarStyle.edge = edge
        context.appBarStyle.outerMargin = outer
        context.appBarStyle.innerMargin = inner
        context.scrolling.appBar.enabled = true
        return context
    }

    @Test("The Space Bar strip sits its outer margin in from the edge")
    func spaceBarOuterMarginInsetsTheStrip() throws {
        let style = spaceBar(edge: .top, outer: 8, inner: 0)
        let strip = try #require(
            SpaceBarGeometry.strip(in: visible, style: style)
        )
        #expect(strip.minY == visible.minY + 8)
        #expect(strip.height == 32)
        #expect(strip.width == visible.width)
        let remaining = SpaceBarGeometry.remainingFrame(
            in: visible,
            style: style
        )
        #expect(remaining.minY == visible.minY + 8 + 32)
    }

    @Test("The Space Bar inner margin reserves room, moving no strip")
    func spaceBarInnerMarginIsAdditive() throws {
        let style = spaceBar(edge: .bottom, outer: 0, inner: 6)
        let strip = try #require(
            SpaceBarGeometry.strip(in: visible, style: style)
        )
        #expect(strip.maxY == visible.maxY)
        let remaining = SpaceBarGeometry.remainingFrame(
            in: visible,
            style: style
        )
        #expect(remaining.maxY == visible.maxY - 32 - 6)
        #expect(style.reservation == 38)
    }

    /// The App Bar's strip is measured from the layout bounds
    /// and the windows keep their outer gap — so the bar stops
    /// reading the inner gap, and at the defaults it is flush.
    @Test("The App Bar is flush by default; windows keep the outer gap")
    func appBarIsFlushAndWindowsKeepTheOuterGap() throws {
        let context = context(
            bounds: visible,
            gaps: Gaps(
                outer: Gaps.Outer(
                    top: 10,
                    bottom: 10,
                    left: 10,
                    right: 10
                ),
                inner: Gaps.Inner(horizontal: 6, vertical: 6)
            ),
            edge: .bottom
        )
        let strip = try #require(
            context.scrolling.barFrame(
                in: context.bounds,
                global: context.appBarStyle
            )
        )
        #expect(strip.maxY == visible.maxY)
        #expect(strip.minX == visible.minX)
        #expect(strip.width == visible.width)
        let area = context.scrolling.windowFrame(
            in: context.bounds,
            outer: context.gaps.outer,
            global: context.appBarStyle
        )
        // Window side: thickness, then the 10 pt OUTER gap —
        // never the 6 pt inner one.
        #expect(area.maxY == visible.maxY - 32 - 10)
    }

    @Test("App Bar margins move the strip in and the windows further")
    func appBarMarginsApply() throws {
        let context = context(
            bounds: visible,
            gaps: .uniform(10),
            edge: .bottom,
            outer: 5,
            inner: 7
        )
        let strip = try #require(
            context.scrolling.barFrame(
                in: context.bounds,
                global: context.appBarStyle
            )
        )
        #expect(strip.maxY == visible.maxY - 5)
        #expect(strip.height == 32)
        let area = context.scrolling.windowFrame(
            in: context.bounds,
            outer: context.gaps.outer,
            global: context.appBarStyle
        )
        #expect(area.maxY == visible.maxY - 5 - 32 - 7 - 10)
    }

    @Test("A per-layout override moves the margins")
    func layoutOverrideResolves() {
        var global = AppBarStyle()
        global.outerMargin = 3
        var bar = LayoutAppBar()
        bar.innerMargin = 9
        let resolved = bar.resolved(with: global)
        #expect(resolved.outerMargin == 3)
        #expect(resolved.innerMargin == 9)
        bar.outerMargin = -4
        #expect(bar.resolved(with: global).outerMargin == 0)
    }

    /// The issue's stacking picture, both bars on one edge:
    /// |SB outer|Space Bar|SB inner|AB outer|App Bar|AB inner|gap|.
    @Test("Both bars on one edge stack outermost-first, margins adding")
    func sameEdgeStacking() throws {
        let space = spaceBar(edge: .top, outer: 2, inner: 3)
        let spaceStrip = try #require(
            SpaceBarGeometry.strip(in: visible, style: space)
        )
        let remaining = SpaceBarGeometry.remainingFrame(
            in: visible,
            style: space
        )
        let context = context(
            bounds: remaining,
            gaps: .uniform(10),
            edge: .top,
            outer: 4,
            inner: 5
        )
        let appStrip = try #require(
            context.scrolling.barFrame(
                in: context.bounds,
                global: context.appBarStyle
            )
        )
        #expect(spaceStrip.minY == visible.minY + 2)
        #expect(appStrip.minY == spaceStrip.maxY + 3 + 4)
        let area = context.scrolling.windowFrame(
            in: context.bounds,
            outer: context.gaps.outer,
            global: context.appBarStyle
        )
        #expect(area.minY == appStrip.maxY + 5 + 10)
    }

    @Test("Absent keys decode to 0 and a negative one is floored")
    func decodingDefaultsAndFloors() throws {
        let decoder = JSONDecoder()
        let bare = try decoder.decode(
            AppBarStyle.self,
            from: Data("{}".utf8)
        )
        #expect(bare.outerMargin == 0)
        #expect(bare.innerMargin == 0)
        let negative = try decoder.decode(
            SpaceBarStyle.self,
            from: Data(
                #"{"outer_margin": -3, "inner_margin": -1}"#.utf8
            )
        )
        #expect(negative.outerMargin == 0)
        #expect(negative.innerMargin == 0)
    }
}

/// The verbs, through the real dispatch: the global setters on
/// both bars and a layout's override.
@Suite("Bar margin commands")
@MainActor
struct BarMarginCommandTests {
    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return makeTestCore(configDirectory: directory)
    }

    @Test("app_bar and space_bar set_*_margin write the leaves")
    func globalSetters() {
        let core = makeCore()
        #expect(
            core.execute(
                "app_bar.set_outer_margin",
                args: [.number(12)]
            ).isSuccess
        )
        #expect(
            core.execute(
                "app_bar.set_inner_margin",
                args: [.number(4)]
            ).isSuccess
        )
        #expect(core.tiler.settings.appBarStyle.outerMargin == 12)
        #expect(core.tiler.settings.appBarStyle.innerMargin == 4)
        #expect(
            core.execute(
                "space_bar.set_outer_margin",
                args: [.number(6)]
            ).isSuccess
        )
        #expect(
            core.execute(
                "space_bar.set_inner_margin",
                args: [.number(-2)]
            ).isSuccess
        )
        #expect(core.tiler.settings.spaceBarStyle.outerMargin == 6)
        #expect(core.tiler.settings.spaceBarStyle.innerMargin == 0)
        #expect(
            !core.execute(
                "app_bar.set_outer_margin",
                args: [.string("x")]
            ).isSuccess
        )
    }

    @Test("scroll and monocle override the App Bar's margins")
    func layoutOverrides() {
        let core = makeCore()
        #expect(
            core.execute(
                "scroll.set_app_bar_outer_margin",
                args: [.number(9)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.scrolling.appBar.outerMargin == 9
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_inner_margin",
                args: [.number(3)]
            ).isSuccess
        )
        #expect(core.tiler.settings.monocle.appBar.innerMargin == 3)
        #expect(core.tiler.settings.appBarStyle.outerMargin == 0)
    }
}
