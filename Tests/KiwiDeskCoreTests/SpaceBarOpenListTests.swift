import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space item whose list a click holds open (#2571 ▸ Ruling): the
/// target stays lit until the list closes, and the `+n` disc keeps
/// its number throughout (owner, device, 2026-10-24).
@Suite("Space Bar open list", .serialized)
@MainActor
struct SpaceBarOpenListTests {
    private static let depth: CGFloat = 32

    /// The pointer pinned off every window, so the lit state reads
    /// the open list alone, never the host's resting pointer.
    init() {
        LiquidGlassGate.override = { false }
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
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
                floating: "#ffffff",
                pocket: "#ffffff"
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

    @Test("An open +n stays lit, its number kept, until it closes")
    func openDiscStaysLit() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        let actions = SpaceBarGlyphActions()
        defer { withExtendedLifetime(actions) {} }
        let view = item(rig, actions)
        let more = try #require(view.overflowTarget)
        open(rig, more)
        #expect(rig.peek.holdsOpen(more))
        #expect(view.hoveredTarget === more, "lit with the pointer away")
        #expect(view.isHovered)
        #expect(view.overflowBadge.stringValue == "+2")
        rig.peek.dismiss()
        #expect(view.hoveredTarget == nil)
        #expect(!view.isHovered)
        #expect(view.overflowBadge.stringValue == "+2")
    }

    @Test("An open glyph stays lit over a neighbour the pointer rests on")
    func openGlyphOutranksTheHover() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        let actions = SpaceBarGlyphActions()
        defer { withExtendedLifetime(actions) {} }
        let view = item(rig, actions)
        let mail = try #require(view.glyphTargets.first)
        let web = try #require(view.glyphTargets.last)
        open(rig, mail)
        #expect(view.hoveredTarget === mail)
        view.applyHover(true, target: web)
        #expect(view.hoveredTarget === mail, "the open one keeps the light")
    }

    /// A list opened on another item takes the open one's place: the
    /// item it leaves is told too, and goes unlit.
    @Test("The item a list leaves goes unlit")
    func leftItemGoesUnlit() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        let actions = SpaceBarGlyphActions()
        defer { withExtendedLifetime(actions) {} }
        let first = item(rig, actions)
        let second = item(rig, actions)
        open(rig, try #require(first.glyphTargets.first))
        #expect(first.isHovered)
        open(rig, try #require(second.glyphTargets.first))
        #expect(second.isHovered)
        #expect(!first.isHovered, "the item it left goes unlit")
        #expect(first.hoveredTarget == nil)
    }
}
