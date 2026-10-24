import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space item whose list a click holds open (#2571 ▸ Ruling): the
/// target stays lit until the list closes, and the `+n` disc reads
/// as a window while its list shows, its count back on close; a
/// multi-window glyph's group badge keeps its number.
@Suite("Space Bar open list", .serialized)
@MainActor
struct SpaceBarOpenListTests {
    private static let depth: CGFloat = 32

    init() {
        LiquidGlassGate.override = { false }
    }

    /// Mail (2, 3) and Web (4) drawn, 5 and 6 behind a trailing `+2`,
    /// on an inactive Space, in the rig's window.
    private func item(
        _ rig: BarPeekRig,
        _ actions: SpaceBarGlyphActions
    ) -> SpaceBarItemView {
        let apps = [(["Mail"], [2, 3]), (["Web"], [4])].map {
            name,
            ids in
            SpaceBarItemView.App(
                name: name[0],
                icon: NSImage(size: NSSize(width: 16, height: 16)),
                glyph: nil,
                focused: false,
                count: ids.count,
                windows: ids.map { WindowID(UInt32($0)) }
            )
        }
        actions.peek = rig.peek
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 200, height: Self.depth)
        )
        view.glyphActions = actions
        rig.item.addSubview(view)
        view.configure(
            identity: .space(SpaceID("2")),
            spaceGlyph: .text("2", tinted: true),
            apps: apps,
            active: false,
            horizontal: true,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            ),
            after: .init(windows: [WindowID(5), WindowID(6)]),
            collapse: nil
        )
        view.layout()
        return view
    }

    private func open(_ rig: BarPeekRig, _ target: SpaceBarGlyphTarget) {
        rig.peek.clicked(
            target,
            source: target.peekSource,
            space: SpaceID("2"),
            edge: .top,
            clickCount: 1
        )
    }

    /// The symbol is an image on the disc, its count blanked: a text
    /// attachment drew nothing in a bar font (device, 2026-10-24).
    private func carriesSymbol(_ badge: NSTextField) -> Bool {
        let symbol = badge.subviews.first {
            $0.identifier == SpaceBarItemView.windowSymbolID
        }
        return (symbol as? NSImageView)?.image != nil
            && badge.stringValue.isEmpty
    }

    @Test("An open +n stays lit and reads as a window until it closes")
    func openDiscReadsAsAWindow() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        let actions = SpaceBarGlyphActions()
        defer { withExtendedLifetime(actions) {} }
        let view = item(rig, actions)
        let more = try #require(view.overflowTarget)
        #expect(view.overflowBadge.stringValue == "+2")
        open(rig, more)
        #expect(rig.peek.holdsOpen(more))
        #expect(view.hoveredTarget === more, "lit with the pointer away")
        #expect(view.isHovered)
        #expect(carriesSymbol(view.overflowBadge))
        rig.peek.dismiss()
        #expect(view.hoveredTarget == nil)
        #expect(!view.isHovered)
        #expect(!carriesSymbol(view.overflowBadge))
        #expect(view.overflowBadge.stringValue == "+2")
    }

    @Test("An open glyph stays lit; no badge swaps for it")
    func openGlyphKeepsItsBadge() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        let actions = SpaceBarGlyphActions()
        defer { withExtendedLifetime(actions) {} }
        let view = item(rig, actions)
        let mail = try #require(view.glyphTargets.first)
        open(rig, mail)
        #expect(view.hoveredTarget === mail)
        #expect(!carriesSymbol(view.overflowBadge))
        #expect(view.overflowBadge.stringValue == "+2")
    }

    @Test("The window symbol is the badge's own ink and size")
    func symbolIsDrawable() throws {
        let symbol = try #require(
            SpaceBarItemView.windowSymbol(size: 11, color: .white)
        )
        #expect(symbol.size.width > 0)
    }
}
