import AppKit
import Testing

@testable import KiwiDeskCore

/// Where the hidden App Bar mark's count comes from (#2567 ▸
/// Ruling): the App Bar's own content — its groups' windows and its
/// floats, a transient dialog left out — reaching the mark through
/// the real `updateBars()`; and the number drawn on its figures
/// band in a tall face (bars.md ▸ every bar text's baseline).
@Suite("Hidden App Bar mark count wiring (#2567)", .serialized)
@MainActor
struct HiddenMarkCountWiringTests {
    /// A monocle Space holding tiled A, B, float F and a dialog.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-markcount-\(UUID().uuidString)")
        )
        core.execute("set_mode", args: [.string("1"), .string("monocle")])
        var dialog = ManagedWindow(
            id: WindowID(4),
            pid: 4,
            appName: "P",
            isFloating: true
        )
        dialog.isTransientOverlay = true
        for window in [
            ManagedWindow(id: WindowID(1), pid: 1, appName: "A"),
            ManagedWindow(
                id: WindowID(3),
                pid: 3,
                appName: "F",
                isFloating: true
            ),
            ManagedWindow(id: WindowID(2), pid: 2, appName: "B"),
            dialog,
        ] {
            core.state.apply(.windowCreated(window))
        }
        return core
    }

    @Test("The count is every window the App Bar draws")
    func countIsTheBars() throws {
        let core = makeCore()
        let space = try #require(core.activeSpace)
        let app = try #require(
            core.appBarContent(space: space, settings: core.tiler.settings)
        )
        let drawn =
            Set(app.groups.flatMap { $0 })
            .union(app.items.filter(\.floating).map(\.id))
        #expect(app.windowCount == drawn.count)
        #expect(app.windowCount == 3)
    }

    @Test(
        "updateBars hands the hidden App Bar mark its count",
        .enabled(if: NSScreen.main != nil)
    )
    func markReadsTheCount() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        for (id, floating) in [(1, false), (2, false), (3, true)] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(900_000 + id)),
                        pid: pid_t(900_000 + id),
                        appName: "Count\(id)",
                        frame: CGRect(x: 100, y: 200, width: 600, height: 400),
                        isFloating: floating
                    )
                )
            )
        }
        core.resolveSpaceDisplays(mainID: display.id)
        let space = try #require(
            core.state.workspaces.space(of: WindowID(900_001))
        )
        core.state.workspaces.setMode(space, .monocle)
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = .auto
        settings.monocle.appBar.visibility = .auto
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        let key = ShelfManager.Key(display: display.id, edge: .top)
        let view = try #require(
            core.shelves.indicators.indicatorForTesting(
                .init(shelf: key, bar: .app)
            )?.view
        )
        let shown = try #require(core.state.workspaces[space])
        let app = try #require(
            core.appBarContent(space: shown, settings: core.tiler.settings)
        )
        #expect(app.windowCount == 3)
        #expect(view.spec?.count?.windows == app.windowCount)
    }

    /// The pill's number sits on its figures band, centred on the
    /// pill, in Apple Chancery at a size where centring its line box
    /// instead misses by more than a point.
    @Test("The count's number centres its figures on the pill")
    func numberOnItsBand() throws {
        let family = BarTextBaselineTests.family
        try #require(BarFont.isInstalled(family))
        var shelf = KiwiShelf()
        shelf.fontFamily = family
        let font = shelf.textFont(ofSize: 40)
        var spec = ShelfIndicatorSpec(
            mark: .line,
            frame: CGRect(x: 0, y: 0, width: 36, height: 8),
            edge: .top,
            fill: "#336699",
            currentInk: "#000000",
            ink: "#AAAAAA",
            emptyInk: "#555555",
            highlight: "#FF0000",
            shown: false,
            hovered: true,
            reveal: .slide,
            rimWidth: 1
        )
        let count = ShelfIndicatorSpec.count(
            11,
            font: font,
            edge: .top,
            pillDepth: spec.pillDepth
        )
        spec.count = count
        let dots = ShelfIndicatorDots(
            frame: CGRect(x: 0, y: 0, width: 300, height: 120)
        )
        dots.mark = CGRect(x: 0, y: 0, width: 300, height: 120)
        dots.spec = spec
        let pill = spec.pill(of: count)
        let lead = 150 - count.content.along / 2
        let columns = Int(lead)...Int(lead + count.number.width)
        let rows = try #require(Self.whiteRows(of: dots, columns: columns))
        let middle =
            rows.upperBound
            - BarTextBaselineTests.bandMiddle(.figures, font: font)
        #expect(abs(middle - 60) <= 1, "figures at \(middle), pill \(pill)")
    }

    /// The rows, in points down from the top, where `view` draws
    /// near-white ink within `columns` — rendered at 2×.
    private static func whiteRows(
        of view: NSView,
        columns: ClosedRange<Int>
    ) -> ClosedRange<CGFloat>? {
        let scale: CGFloat = 2
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(view.bounds.width * scale),
                pixelsHigh: Int(view.bounds.height * scale),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else { return nil }
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        var hits: [Int] = []
        for y in 0..<rep.pixelsHigh {
            for x in (columns.lowerBound * 2)...(columns.upperBound * 2)
            where x < rep.pixelsWide {
                guard let colour = rep.colorAt(x: x, y: y),
                    colour.alphaComponent > 0.9,
                    colour.redComponent > 0.9, colour.greenComponent > 0.9
                else { continue }
                hits.append(y)
                break
            }
        }
        guard let first = hits.first, let last = hits.last else { return nil }
        return CGFloat(first) / scale...CGFloat(last + 1) / scale
    }
}
