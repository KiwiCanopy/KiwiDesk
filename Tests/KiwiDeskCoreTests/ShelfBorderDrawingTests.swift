import AppKit
import Testing

@testable import KiwiDeskCore

/// The border reaches every surface it rims (#1679), built
/// through the real views: the shelf's plate under Plain, each
/// item's box under Boxed on both bars, and the Space Bar's
/// front-app chip — and nothing while the switch is off.
@Suite("Shelf border drawing")
@MainActor
struct ShelfBorderDrawingTests {
    private static let width: CGFloat = 3
    private static let color = "#FF000080"

    /// The machine's Reduce transparency setting is a default this
    /// fixture reasons from, so it is pinned off (#660, #1374).
    init() { LiquidGlassGate.override = { false } }

    private static func bordered(
        _ shelf: KiwiShelf = KiwiShelf(),
        on: Bool = true
    ) -> KiwiShelf {
        var shelf = shelf
        shelf.border = on
        shelf.borderWidth = width
        shelf.borderColor = color
        return shelf
    }

    /// `view` strokes the shelf's border: shown, at the width, in
    /// the colour, on `bounds`-sized frame `frame`.
    private func expectStroke(
        _ view: NSView,
        frame: CGRect,
        _ comment: Comment? = nil
    ) {
        #expect(!view.isHidden, comment)
        #expect(view.layer?.borderWidth == Self.width, comment)
        #expect(
            view.layer?.borderColor
                == NSColor(kiwiHex: Self.color).cgColor,
            comment
        )
        #expect(view.layer?.backgroundColor == nil, comment)
        #expect(view.frame == frame, comment)
    }

    // MARK: - Boxes

    /// An active item; the edge mark by default, which keeps the
    /// rim an outline would stand down (#1924).
    private func spaceItem(
        _ shelf: KiwiShelf,
        active: Bool = true,
        indicator: SpaceBarStyle.ActiveIndicator = .edgeMark
    ) -> SpaceBarItemView {
        var bar = SpaceBarStyle()
        bar.activeIndicator = indicator
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 80, height: 40)
        )
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: [],
            active: active,
            horizontal: true,
            style: SpaceBarLook(
                shelf: shelf,
                bar: bar,
                sheen: 0
            ),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        view.layout()
        return view
    }

    private func appItem(
        _ shelf: KiwiShelf,
        active: Bool = true,
        indicator: AppBarStyle.ActiveIndicator = .edgeMark
    ) -> AppBarItemView {
        var bar = AppBarStyle()
        bar.activeIndicator = indicator
        let view = AppBarItemView(
            frame: NSRect(x: 0, y: 0, width: 120, height: 40)
        )
        view.configure(
            id: WindowID(1),
            text: "Zed",
            icon: nil,
            glyph: nil,
            count: 1,
            active: active,
            horizontal: true,
            style: AppBarLook(
                shelf: shelf,
                bar: bar,
                sheen: 0
            )
        )
        view.layout()
        return view
    }

    private static func boxed(glass: Bool) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.backgroundStyle = .boxed
        shelf.liquidGlass = glass
        return shelf
    }

    /// Solid boxes and glass ones alike: under glass the item
    /// view is the glass's content, so it carries the rim too.
    @Test("Both bars' boxes stroke the border", arguments: [false, true])
    func boxesStroke(glass: Bool) {
        let shelf = Self.bordered(Self.boxed(glass: glass))
        let space = spaceItem(shelf)
        expectStroke(space.boxBorder, frame: space.bounds, "space")
        #expect(space.boxBorder.layer?.cornerRadius == space.cornerRadius)
        let app = appItem(shelf)
        expectStroke(app.boxBorder, frame: app.bounds, "app")
        #expect(
            app.boxBorder.layer?.cornerRadius
                == app.style.resolvedCornerRadius(
                    forThickness: app.crossThickness
                )
        )
    }

    /// The active outline strokes OVER the border, never under it.
    @Test("A box's border sits beneath the active outline")
    func borderBeneathOutline() {
        let shelf = Self.bordered(Self.boxed(glass: false))
        let space = spaceItem(shelf)
        let app = appItem(shelf)
        for (view, border, clip) in [
            (space as NSView, space.boxBorder, space.accentClip),
            (app, app.boxBorder, app.accentClip),
        ] {
            let order = view.subviews
            let rim = order.firstIndex(of: border)
            let accent = order.firstIndex(of: clip)
            #expect(rim != nil && accent != nil && rim! < accent!)
        }
    }

    @Test("Plain items and a switched-off border draw no box rim")
    func noRimOffOrPlain() {
        var plain = Self.bordered()
        plain.backgroundStyle = .plain
        let off = Self.bordered(Self.boxed(glass: false), on: false)
        for shelf in [plain, off] {
            #expect(spaceItem(shelf).boxBorder.isHidden)
            #expect(appItem(shelf).boxBorder.isHidden)
        }
    }

    /// The active outline strokes the box's edge itself, so the
    /// rim beneath it stands down; an idle box and an edge-marked
    /// active one keep theirs (#1924), solid or under glass.
    @Test(
        "An active outline stands the box rim down",
        arguments: [false, true]
    )
    func outlineStandsTheRimDown(glass: Bool) {
        let shelf = Self.bordered(Self.boxed(glass: glass))
        #expect(spaceItem(shelf, indicator: .outline).boxBorder.isHidden)
        #expect(appItem(shelf, indicator: .outline).boxBorder.isHidden)
        let idle = spaceItem(shelf, active: false, indicator: .outline)
        expectStroke(idle.boxBorder, frame: idle.bounds, "idle space")
        let idleApp = appItem(shelf, active: false, indicator: .outline)
        expectStroke(idleApp.boxBorder, frame: idleApp.bounds, "idle app")
        let marked = spaceItem(shelf, indicator: .edgeMark)
        expectStroke(marked.boxBorder, frame: marked.bounds, "mark")
        let markedApp = appItem(shelf, indicator: .edgeMark)
        expectStroke(
            markedApp.boxBorder,
            frame: markedApp.bounds,
            "app mark"
        )
    }

    /// The chip IS the focused window, so its outline is always
    /// drawn and its rim always stands down under it.
    @Test("The front-app chip's outline stands its rim down")
    func frontChipOutlineStandsTheRimDown() throws {
        let shelf = Self.bordered(Self.boxed(glass: false))
        let outlined = try frontOverlay(shelf, indicator: .outline)
        #expect(outlined.frontBorder.isHidden)
        let marked = try frontOverlay(shelf, indicator: .edgeMark)
        expectStroke(marked.frontBorder, frame: marked.frontBox.frame)
    }

    // MARK: - The front-app chip

    private func frontOverlay(
        _ shelf: KiwiShelf,
        indicator: SpaceBarStyle.ActiveIndicator = .edgeMark
    ) throws -> SpaceBarOverlay {
        let base = paintedSpaceBar(front: WindowID(1))
        var style = base.style
        style.shelf = shelf
        style.bar.activeIndicator = indicator
        let bar = SpaceBarManager.Bar(
            display: base.display,
            items: base.items,
            frontApp: base.frontApp,
            frontWindow: base.frontWindow,
            strip: base.strip,
            style: style,
            stateMarkColors: base.stateMarkColors
        )
        let manager = SpaceBarManager()
        manager.sync([bar])
        return try #require(manager.overlayForTesting(barTitleDisplay))
    }

    @Test("The front-app chip strokes the border")
    func frontChipStrokes() throws {
        let overlay = try frontOverlay(
            Self.bordered(Self.boxed(glass: false))
        )
        expectStroke(overlay.frontBorder, frame: overlay.frontBox.frame)
        let off = try frontOverlay(
            Self.bordered(Self.boxed(glass: false), on: false)
        )
        #expect(off.frontBorder.isHidden)
    }

    /// Under box glass the chip's rim strokes ABOVE its glass, so
    /// the material never covers it.
    @Test("The front-app chip's rim sits above its glass")
    func frontChipRimAboveGlass() throws {
        guard #available(macOS 26, *) else { return }
        let overlay = try frontOverlay(
            Self.bordered(Self.boxed(glass: true))
        )
        let glass = try #require(overlay.frontGlass)
        #expect(!glass.isHidden)
        expectStroke(overlay.frontBorder, frame: glass.frame)
        let host = try #require(glass.superview)
        #expect(overlay.frontBorder.superview === host)
        let order = host.subviews
        let rim = try #require(order.firstIndex(of: overlay.frontBorder))
        #expect(try #require(order.firstIndex(of: glass)) < rim)
    }
}
