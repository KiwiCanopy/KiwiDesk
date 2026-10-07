import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// An App Bar item's hover peek (#1514's ruling, #1946): it asks
/// only where the item hides text — a title Core cut at the cap, a
/// label its width truncates, or no label drawn — for its windows,
/// which Core turns into the app and every title when it shows.
@Suite("App Bar hover peek", .serialized)
@MainActor
struct AppBarHoverTitleTests {
    init() {
        LiquidGlassGate.override = { false }
    }

    private func core(title: String) -> KiwiCore {
        let core = makeBarCore()
        core.state.apply(
            .windowCreated(titledWindow(1, app: "Finder", title: title))
        )
        return core
    }

    private func titles(
        _ core: KiwiCore,
        _ source: BarPeekSource?
    ) -> [String]? {
        source.flatMap(core.barPeekContent)?.groups.flatMap(\.titles)
    }

    @Test("The peek is the app, then the full title")
    func titleShape() throws {
        let core = core(title: "Downloads")
        let content = try #require(
            core.barPeekContent(.appItem([WindowID(1)]))
        )
        #expect(content.groups.map(\.app) == ["Finder"])
        #expect(content.groups.map(\.titles) == [["Downloads"]])
        // One window: the name alone, no count.
        #expect(content.groups.first?.count == nil)
        // An App Bar header carries no icon; `+n` alone mixes apps.
        #expect(content.groups.first?.icon == nil)
        #expect(core.barPeekContent(.appItem([WindowID(99)])) == nil)
    }

    @Test("Core marks an item whose title it cut")
    func coreMarksTheCut() {
        let core = core(title: String(repeating: "x", count: 80))
        var style = AppBarLook()
        style.titleCap = 20
        #expect(core.barItem(for: [WindowID(1)], style: style).titleCut)
        style.titleCap = 100
        #expect(!core.barItem(for: [WindowID(1)], style: style).titleCut)
        #expect(
            !core.barItem(for: [WindowID(1), WindowID(1)], style: style)
                .titleCut
        )
    }

    private func item(
        _ core: KiwiCore,
        edge: AppBarEdge = .top,
        titleCut: Bool = false
    ) throws -> AppBarItemView {
        core.appBars.sync([
            paintedAppBar(
                edge: edge,
                items: [
                    AppBarOverlay.Item(
                        id: WindowID(1),
                        text: "Downloads",
                        icon: nil,
                        titleCut: titleCut
                    )
                ]
            )
        ])
        let overlay = try #require(
            core.appBars.overlayForTesting(barTitleDisplay)
        )
        let view = try #require(overlay.itemViews.first)
        view.layout()
        return view
    }

    @Test("A whole title owes no peek; hidden text and a group do")
    func onlyHiddenTextAsks() throws {
        let core = core(title: "Downloads")
        let shown = try item(core)
        #expect(shown.drawsTextInFull)
        #expect(shown.peekSource == nil)
        let cut = try item(core, titleCut: true)
        #expect(cut.peekSource == .appItem([WindowID(1)]))
        #expect(titles(core, cut.peekSource) == ["Downloads"])
        // A group peeks its windows even with its name drawn whole,
        // as a multi-window glyph does (owner, #1946).
        core.state.apply(
            .windowCreated(titledWindow(2, app: "Finder", title: "Desktop"))
        )
        core.appBars.sync([
            paintedAppBar(
                items: [
                    AppBarOverlay.Item(
                        id: WindowID(1),
                        text: "Finder",
                        icon: nil,
                        count: 2,
                        members: [WindowID(1), WindowID(2)]
                    )
                ]
            )
        ])
        let overlay = try #require(
            core.appBars.overlayForTesting(barTitleDisplay)
        )
        let group = try #require(overlay.itemViews.first)
        group.layout()
        #expect(group.drawsTextInFull)
        #expect(group.peekSource == .appItem([WindowID(1), WindowID(2)]))
    }

    @Test("A vertical bar's item draws no label and owes the title")
    func verticalItemOwesTheTitle() throws {
        let core = core(title: "Downloads")
        let view = try item(core, edge: .left)
        #expect(!view.drawsTextInFull)
        #expect(titles(core, view.peekSource) == ["Downloads"])
    }

    @Test("A narrow item's layout truncates its label")
    func narrowItemTruncates() throws {
        let core = core(title: "Downloads")
        let view = try item(core)
        view.setFrameSize(NSSize(width: 44, height: view.bounds.height))
        view.layout()
        #expect(!view.drawsTextInFull)
        // Hidden, whatever its frame still says.
        view.label.frame.size.width = 500
        view.label.isHidden = true
        #expect(!view.drawsTextInFull)
    }

    /// The item hands the peek its WINDOWS, never a string, so the
    /// title is whatever state holds when the peek shows.
    @Test("The peek is read when it shows, never stored")
    func peekIsReadAtShow() throws {
        let core = core(title: "Downloads")
        let view = try item(core, edge: .left)
        let source = view.peekSource
        #expect(titles(core, source) == ["Downloads"])
        core.state.windows.updateTitle(WindowID(1), title: "Desktop")
        #expect(titles(core, view.peekSource) == ["Desktop"])
    }

    /// A collapsed group draws its app name, so where it hides that
    /// it peeks EVERY member's title with the count — every window
    /// counts (#1946), which retires #1514's "a group lists no
    /// title" for the peek.
    @Test("A collapsed group's peek lists every member")
    func groupListsEveryMember() throws {
        let core = core(title: "Downloads")
        core.state.apply(
            .windowCreated(titledWindow(2, app: "Finder", title: "Desktop"))
        )
        core.appBars.sync([
            paintedAppBar(
                edge: .left,
                items: [
                    AppBarOverlay.Item(
                        id: WindowID(1),
                        text: "Finder",
                        icon: nil,
                        count: 2,
                        members: [WindowID(1), WindowID(2)]
                    )
                ]
            )
        ])
        let overlay = try #require(
            core.appBars.overlayForTesting(barTitleDisplay)
        )
        let view = try #require(overlay.itemViews.first)
        view.layout()
        #expect(view.peekSource == .appItem([WindowID(1), WindowID(2)]))
        let content = try #require(
            view.peekSource.flatMap(core.barPeekContent)
        )
        #expect(content.groups.map(\.app) == ["Finder"])
        #expect(content.groups.map(\.titles) == [["Downloads", "Desktop"]])
        #expect(content.groups.map(\.count) == [2])
    }

    @Test("An item reports its hover to the shelf's one peek")
    func itemReachesThePeek() throws {
        let core = core(title: "Downloads")
        let view = try item(core, edge: .left)
        #expect(view.itemActions?.peek === core.shelves.peek)
        #expect(
            core.spaceBars.glyphActions.peek === core.shelves.peek
        )
    }
}
