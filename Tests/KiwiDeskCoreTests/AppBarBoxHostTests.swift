import AppKit
import Testing

@testable import KiwiDeskCore

/// A boxed glass App Bar keeps each glass and its tint in the
/// `BoxHost` it was minted in (#1842), whatever moves the box: a
/// drag fronts the host, a dissolve stands an arrival's host
/// transparent, and a run turning bare fades a leaving view on its
/// own rather than in a box the render is about to drop.
@Suite("App Bar box hosts", .serialized)
@MainActor
struct AppBarBoxHostTests {
    private func item(_ id: UInt32) -> AppBarOverlay.Item {
        AppBarOverlay.Item(
            id: WindowID(id),
            name: "App",
            text: "App",
            icon: nil,
            count: 1,
            members: nil
        )
    }

    private func boxedOverlay(_ ids: [UInt32]) -> AppBarOverlay {
        var style = AppBarLook()
        style.liquidGlass = true
        style.backgroundStyle = .boxed
        let overlay = AppBarOverlay()
        overlay.show(
            items: ids.map(item),
            activeIndex: nil,
            strip: CGRect(x: 0, y: 0, width: 900, height: 30),
            style: style,
            space: SpaceID("1")
        )
        return overlay
    }

    @Test("A dragged box fronts its host and keeps its glass in it")
    func dragFrontsTheHost() throws {
        guard #available(macOS 26, *) else { return }
        let gate = LiquidGlassGate.override
        defer { LiquidGlassGate.override = gate }
        LiquidGlassGate.override = { false }
        let overlay = boxedOverlay([1, 2, 3])
        let view = try #require(overlay.itemViews.first)
        let glass = overlay.draggableView(for: view)
        let host = try #require(AppBarOverlay.boxHost(of: glass))

        overlay.dragMoved(view, to: .zero)

        #expect(glass.superview === host)
        #expect(overlay.itemRun.subviews.last === host)
    }

    @Test("A dissolve stands an arriving box's host transparent")
    func arrivalHostStandsTransparent() throws {
        guard #available(macOS 26, *) else { return }
        let gate = LiquidGlassGate.override
        defer { LiquidGlassGate.override = gate }
        LiquidGlassGate.override = { false }
        let overlay = boxedOverlay([1])

        let sync = overlay.syncItemViews(
            to: [item(7)],
            glass: true,
            dissolving: true
        )
        overlay.standArrivals(sync.arrivals)

        let glass = try #require(overlay.boxGlasses.first)
        let host = try #require(AppBarOverlay.boxHost(of: glass))
        #expect(host.alphaValue == 0)
    }

    @Test("A run turning bare fades a leaving view outside its box")
    func bareRunFadesTheViewItself() throws {
        guard #available(macOS 26, *) else { return }
        let gate = LiquidGlassGate.override
        defer { LiquidGlassGate.override = gate }
        LiquidGlassGate.override = { false }
        let overlay = boxedOverlay([1])
        let leaving = try #require(overlay.itemViews.first)

        let sync = overlay.syncItemViews(
            to: [item(7)],
            glass: false,
            dissolving: true
        )

        let departure = try #require(sync.departures.first)
        #expect(departure.box == nil)
        #expect(leaving.superview === overlay.itemRun)
    }
}
