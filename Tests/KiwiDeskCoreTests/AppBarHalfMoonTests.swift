import AppKit
import Testing

@testable import KiwiDeskCore

/// The half-moon (#2234): drawn before the icon — above it on a
/// vertical bar — only for a partly visible window, the half on the
/// shown side filled, a covered window's ring empty, never dimmed,
/// and its slot reserved on every item.
@Suite("App Bar half-moon")
@MainActor
struct AppBarHalfMoonTests {
    private static let depth: CGFloat = 32

    private func item(
        _ visibility: BarVisibility,
        edge: AppBarEdge = .top
    ) -> AppBarItemView {
        var look = AppBarLook()
        look.edge = edge
        look.shelf.dimFactor = 0.4
        let horizontal = edge.isHorizontal
        let view = AppBarItemView(
            frame: horizontal
                ? CGRect(x: 0, y: 0, width: 160, height: Self.depth)
                : CGRect(x: 0, y: 0, width: Self.depth, height: 60)
        )
        view.configure(
            id: WindowID(1),
            name: "Safari",
            text: "Downloads",
            icon: NSImage(size: NSSize(width: 16, height: 16)),
            glyph: nil,
            count: 1,
            visibility: visibility,
            active: false,
            horizontal: horizontal,
            style: look
        )
        view.layoutSubtreeIfNeeded()
        view.halfMoon.layoutSubtreeIfNeeded()
        return view
    }

    @Test("Only a partly visible window draws the half-moon")
    func onlyPartlyDraws() {
        #expect(item(.visible).halfMoon.isHidden)
        #expect(item(.hidden).halfMoon.isHidden)
        #expect(!item(.partly(shown: .left)).halfMoon.isHidden)
        let covered = item(.partly(shown: nil)).halfMoon
        #expect(!covered.isHidden)
        #expect(covered.ring.path != nil)
        #expect(covered.half.path == nil)
    }

    @Test("It sits before the icon, sized off the content depth")
    func sitsBeforeTheIcon() {
        let view = item(.partly(shown: .right))
        let moon = view.halfMoon.frame
        let depth = view.style.contentDepth(forDepth: Self.depth)
        #expect(
            moon.width == AppBarHalfMoon.diameter(contentDepth: depth)
        )
        #expect(moon.width >= 5)
        #expect(moon.maxX <= view.iconView.frame.minX)
        #expect(abs(moon.midY - view.iconView.frame.midY) <= 0.5)
        #expect(view.halfMoon.alphaValue == 1)
        #expect(view.iconView.alphaValue == 0.4)
    }

    @Test("On a side bar it sits above the icon")
    func sitsAboveOnASideBar() {
        let view = item(.partly(shown: .top), edge: .left)
        let moon = view.halfMoon.frame
        #expect(moon.maxY <= view.iconView.frame.minY)
        #expect(abs(moon.midX - view.iconView.frame.midX) <= 0.5)
    }

    @Test("The filled half is the side still on screen")
    func halfFollowsTheSide() {
        let box = CGRect(x: 0, y: 0, width: 10, height: 10)
        let half = { (side: BarVisibility.Side) in
            AppBarHalfMoon.halfPath(in: box, side: side)
        }
        let left = CGPoint(x: 2, y: 5)
        let right = CGPoint(x: 8, y: 5)
        let top = CGPoint(x: 5, y: 2)
        let bottom = CGPoint(x: 5, y: 8)
        #expect(half(.left).contains(left))
        #expect(!half(.left).contains(right))
        #expect(half(.right).contains(right))
        #expect(!half(.right).contains(left))
        // Flipped space: the top is the low y.
        #expect(half(.top).contains(top))
        #expect(!half(.top).contains(bottom))
        #expect(half(.bottom).contains(bottom))
    }

    @Test("Every item reserves the slot, so lengths never move")
    func slotIsReserved() {
        let look = AppBarLook()
        let depth = look.contentDepth(forDepth: Self.depth)
        let view = item(.visible)
        let placed = view.horizontalPlacement(in: view.bounds.size)
        #expect(placed.moon == AppBarHalfMoon.reserve(contentDepth: depth))
        #expect(
            view.iconView.frame.minX == placed.x + placed.moon
        )
    }
}
