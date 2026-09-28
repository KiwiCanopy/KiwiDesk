import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// An App Bar item's hover title (#1514's ruling): it shows only
/// where the item hides text — a title cut by the cap or by its
/// width, or no label drawn — as the app, then the full title,
/// asked of Core when it shows.
@Suite("App Bar hover title", .serialized)
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

    @Test("Text drawn in full owes no tooltip; hidden text does")
    func onlyHiddenTextOwesATooltip() {
        let core = core(title: "Downloads")
        let read = { (count: Int, drawn: String?) in
            core.appBarHoverTitle(
                window: WindowID(1),
                count: count,
                drawn: drawn
            )
        }
        #expect(read(1, "Downloads") == nil)
        #expect(read(1, "Downl…") == "Finder\nDownloads")
        #expect(read(1, nil) == "Finder\nDownloads")
        // A group's text is its app name.
        #expect(read(2, "Finder") == nil)
        #expect(read(2, nil) == "Finder")
        #expect(
            core.appBarHoverTitle(
                window: WindowID(99),
                count: 1,
                drawn: nil
            ) == nil
        )
    }

    @Test("An untitled window's item draws its app name in full")
    func untitledWindowNamesItsApp() {
        let core = core(title: "")
        #expect(
            core.appBarHoverTitle(
                window: WindowID(1),
                count: 1,
                drawn: "Finder"
            ) == nil
        )
    }

    private func item(
        _ core: KiwiCore,
        content: AppBarStyle.Content,
        edge: AppBarEdge = .top
    ) throws -> AppBarItemView {
        core.appBars.sync([
            paintedAppBar(
                content: content,
                edge: edge,
                items: [appBarItem(1, text: "Downloads")]
            )
        ])
        let overlay = try #require(
            core.appBars.overlayForTesting(barTitleDisplay)
        )
        let view = try #require(overlay.itemViews.first)
        view.layout()
        return view
    }

    private func tooltip(_ view: AppBarItemView) -> String {
        view.view(view, stringForToolTip: 0, point: .zero, userData: nil)
    }

    @Test("A rendered item asks Core only when its label hides text")
    func renderedItemAsksCore() throws {
        let core = core(title: "Downloads")
        let shown = try item(core, content: .iconAndTitle)
        #expect(shown.fullyDrawnText == "Downloads")
        #expect(tooltip(shown) == "")
        let icon = try item(core, content: .icon)
        #expect(icon.fullyDrawnText == nil)
        #expect(tooltip(icon) == "Finder\nDownloads")
    }

    @Test("A vertical bar's item draws no label and owes the title")
    func verticalItemOwesTheTitle() throws {
        let core = core(title: "Downloads")
        let view = try item(core, content: .iconAndTitle, edge: .left)
        #expect(view.fullyDrawnText == nil)
        #expect(tooltip(view) == "Finder\nDownloads")
    }

    @Test("A label its width truncates is not drawn in full")
    func widthTruncationHidesText() throws {
        let core = core(title: "Downloads")
        let view = try item(core, content: .iconAndTitle)
        view.label.frame.size.width = 10
        #expect(view.fullyDrawnText == nil)
        // Hidden, whatever its frame still says.
        view.label.frame.size.width = 500
        view.label.isHidden = true
        #expect(view.fullyDrawnText == nil)
    }
}
