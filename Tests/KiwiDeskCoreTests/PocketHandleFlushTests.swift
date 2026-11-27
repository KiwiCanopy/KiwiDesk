import AppKit
import Testing

@testable import KiwiDeskCore

/// The Pocket's tab rests flush on the screen edge at a bar handle's
/// depth, so an edge where both rest reads as one row of handles
/// (#3696): its edge-side span across the edge is the bar handle's,
/// on every edge, with an outer margin that would part them.
@Suite(
    "Pocket handle flush (#3696)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketHandleFlushTests {
    private func core(edge: AppBarEdge) throws -> (KiwiCore, Display) {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.resolveSpaceDisplays(mainID: display.id)
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(edge)
        settings.spaceBarStyle.visibility = .auto
        settings.appBarStyle.setEdge(edge == .top ? .bottom : .top)
        settings.kiwishelf.pocketEdge = edge
        settings.kiwishelf.pocketVisibility = .auto
        settings.kiwishelf.handleThickness = 4
        settings.kiwishelf.outerMargin = 4
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        pinRevealLength()
        core.updateBars()
        return (core, display)
    }

    /// The span across `edge` (AX): y on a horizontal edge, x on a
    /// side one.
    private func across(
        _ rect: CGRect,
        _ edge: AppBarEdge
    ) -> ClosedRange<CGFloat> {
        edge.isHorizontal
            ? rect.minY...rect.maxY : rect.minX...rect.maxX
    }

    @Test(
        "the tab sits where the bar handle does",
        arguments: [AppBarEdge.top, .bottom, .left, .right]
    )
    func tabMatchesTheBarHandle(edge: AppBarEdge) throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try core(edge: edge)
        let key = ShelfRevealer.Key(
            shelf: ShelfManager.Key(
                placement: PlacementID(display: display.id, area: 0),
                edge: edge
            ),
            bar: .space
        )
        let bar = try #require(
            core.shelves.handles.handleForTesting(key)?.view.spec
        )
        let spec = try #require(core.pocketPlate.specs[display.id])
        #expect(spec.handle == edge)
        let view = try #require(core.pocketPlate.view(on: display.id))
        view.layoutSubtreeIfNeeded()
        // The panel in AX, the views flipped alike.
        let panel = GeometryUtils.flip(
            spec.frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        let tab = view.handle.tabRect()
            .applying(view.handle.drawingTurn())
            .offsetBy(
                dx: panel.minX + view.handle.frame.minX,
                dy: panel.minY + view.handle.frame.minY
            )
        let want = across(bar.frame, edge)
        let got = across(tab, edge)
        #expect(abs(got.lowerBound - want.lowerBound) < 0.001)
        #expect(abs(got.upperBound - want.upperBound) < 0.001)
        // The panel itself starts at the edge too, not a margin in.
        let side = across(panel, edge)
        let flush =
            edge == .top || edge == .left
            ? abs(side.lowerBound - want.lowerBound)
            : abs(side.upperBound - want.upperBound)
        #expect(flush < 0.001)
    }
}
