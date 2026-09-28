import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// An App Bar item's hover title (#1514's ruling): it shows only
/// where the item hides text — a title Core cut at the cap, a
/// label its width truncates, or no label drawn — as the app, then
/// the full title, asked of Core when it shows.
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

    @Test("The hover title is the app, then the full title")
    func titleShape() {
        let core = core(title: "Downloads")
        #expect(
            core.appBarHoverTitle(window: WindowID(1), count: 1)
                == "Finder\nDownloads"
        )
        // A group's text is its app name.
        #expect(
            core.appBarHoverTitle(window: WindowID(1), count: 2)
                == "Finder"
        )
        #expect(
            core.appBarHoverTitle(window: WindowID(99), count: 1) == nil
        )
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
        content: AppBarStyle.Content,
        edge: AppBarEdge = .top,
        titleCut: Bool = false
    ) throws -> AppBarItemView {
        core.appBars.sync([
            paintedAppBar(
                content: content,
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

    private func tooltip(_ view: AppBarItemView) -> String {
        view.view(view, stringForToolTip: 0, point: .zero, userData: nil)
    }

    @Test("A rendered item registers its tooltip over its bounds")
    func tooltipIsRegistered() throws {
        let core = core(title: "Downloads")
        let view = try item(core, content: .icon)
        #expect(view.tipTag != nil)
        #expect(view.bounds.width > 0)
    }

    @Test("A fully drawn title owes no tooltip; hidden text does")
    func onlyHiddenTextAsks() throws {
        let core = core(title: "Downloads")
        let shown = try item(core, content: .iconAndTitle)
        #expect(shown.drawsTextInFull)
        #expect(tooltip(shown) == "")
        let cut = try item(core, content: .iconAndTitle, titleCut: true)
        #expect(tooltip(cut) == "Finder\nDownloads")
        let icon = try item(core, content: .icon)
        #expect(!icon.drawsTextInFull)
        #expect(tooltip(icon) == "Finder\nDownloads")
    }

    @Test("A vertical bar's item draws no label and owes the title")
    func verticalItemOwesTheTitle() throws {
        let core = core(title: "Downloads")
        let view = try item(
            core,
            content: .iconAndTitle,
            edge: .left
        )
        #expect(!view.drawsTextInFull)
        #expect(tooltip(view) == "Finder\nDownloads")
    }

    @Test("A narrow item's layout truncates its label")
    func narrowItemTruncates() throws {
        let core = core(title: "Downloads")
        let view = try item(core, content: .iconAndTitle)
        view.setFrameSize(NSSize(width: 44, height: view.bounds.height))
        view.layout()
        #expect(!view.drawsTextInFull)
        // Hidden, whatever its frame still says.
        view.label.frame.size.width = 500
        view.label.isHidden = true
        #expect(!view.drawsTextInFull)
    }

    @Test("The tooltip is read when it shows, never stored")
    func tooltipIsReadAtHover() throws {
        let core = core(title: "Downloads")
        let view = try item(core, content: .icon)
        #expect(tooltip(view) == "Finder\nDownloads")
        core.state.windows.updateTitle(WindowID(1), title: "Desktop")
        #expect(tooltip(view) == "Finder\nDesktop")
    }
}
