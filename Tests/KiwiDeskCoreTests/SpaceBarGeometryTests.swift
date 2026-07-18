import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Space-first reservation math (#293): strips on all four
/// edges, disabled combinations, same-edge and perpendicular
/// stacking with the App Bar, and the combined float clamp.
@Suite("Space bar geometry")
struct SpaceBarGeometryTests {
    private let visible = CGRect(
        x: 0,
        y: 25,
        width: 1920,
        height: 1055
    )

    private func style(
        edge: AppBarEdge,
        enabled: Bool = true,
        thickness: CGFloat = 32
    ) -> SpaceBarStyle {
        var style = SpaceBarStyle()
        style.enabled = enabled
        style.edge = edge
        style.thickness = thickness
        return style
    }

    @Test(
        "Strip hugs its edge and remaining frame loses it",
        arguments: [AppBarEdge.top, .bottom, .left, .right]
    )
    func reservation(edge: AppBarEdge) throws {
        let style = style(edge: edge)
        let strip = try #require(
            SpaceBarGeometry.strip(in: visible, style: style)
        )
        let remaining = SpaceBarGeometry.remainingFrame(
            in: visible,
            style: style
        )
        // Strip and remaining frame partition the visible frame:
        // disjoint, and their union spans it.
        #expect(visible.contains(strip))
        #expect(visible.contains(remaining))
        #expect(!strip.intersects(remaining))
        #expect(
            strip.width * strip.height
                + remaining.width * remaining.height
                == visible.width * visible.height
        )
        switch edge {
        case .top:
            #expect(strip.minY == visible.minY)
            #expect(remaining.minY == visible.minY + 32)
        case .bottom:
            #expect(strip.maxY == visible.maxY)
            #expect(remaining.maxY == visible.maxY - 32)
        case .left:
            #expect(strip.minX == visible.minX)
            #expect(remaining.minX == visible.minX + 32)
        case .right:
            #expect(strip.maxX == visible.maxX)
            #expect(remaining.maxX == visible.maxX - 32)
        }
    }

    @Test("A disabled bar reserves nothing")
    func disabled() {
        let style = style(edge: .left, enabled: false)
        #expect(
            SpaceBarGeometry.strip(in: visible, style: style)
                == nil
        )
        #expect(
            SpaceBarGeometry.remainingFrame(
                in: visible,
                style: style
            ) == visible
        )
    }

    @Test("Oversized thickness never yields a negative frame")
    func oversized() {
        let style = style(edge: .top, thickness: 5000)
        let remaining = SpaceBarGeometry.remainingFrame(
            in: visible,
            style: style
        )
        #expect(remaining.height == 0)
        #expect(remaining.width == visible.width)
    }

    /// Same edge: the App Bar carves from the already-inset
    /// frame, so the Space Bar is screen-facing, the App Bar
    /// window-facing, and the insets add.
    @Test("Same-edge stacking: space bar outer, app bar inner")
    func sameEdgeStacking() throws {
        let space = style(edge: .top)
        let remaining = SpaceBarGeometry.remainingFrame(
            in: visible,
            style: space
        )
        let spaceStrip = try #require(
            SpaceBarGeometry.strip(in: visible, style: space)
        )
        var appStyle = AppBarStyle()
        appStyle.edge = .top
        let appStrip = AppBarGeometry.barFrame(
            in: remaining,
            edge: .top,
            thickness: appStyle.thickness
        )
        #expect(spaceStrip.maxY == appStrip.minY)
        #expect(!spaceStrip.intersects(appStrip))
        // Combined inset = sum of both strips.
        #expect(
            appStrip.maxY == visible.minY + 32 + 32
        )
    }

    /// Perpendicular edges: the App Bar strip spans the inset
    /// frame, so it starts inside the Space Bar's inset — the
    /// corner cannot overlap.
    @Test("Perpendicular edges never overlap at the corner")
    func perpendicularCorner() throws {
        let space = style(edge: .left)
        let remaining = SpaceBarGeometry.remainingFrame(
            in: visible,
            style: space
        )
        let spaceStrip = try #require(
            SpaceBarGeometry.strip(in: visible, style: space)
        )
        let appStrip = AppBarGeometry.barFrame(
            in: remaining,
            edge: .bottom,
            thickness: 32
        )
        #expect(!spaceStrip.intersects(appStrip))
        #expect(appStrip.minX == spaceStrip.maxX)
    }

    /// The #242 clamp applies to the space bar strip the same
    /// way: a float under a top strip is pushed below it.
    @Test("Float clamp clears a top space bar strip")
    func floatClamp() throws {
        let style = style(edge: .top)
        let strip = try #require(
            SpaceBarGeometry.strip(in: visible, style: style)
        )
        let float = CGRect(
            x: 100,
            y: visible.minY + 4,
            width: 400,
            height: 300
        )
        let clamped = AppBarGeometry.clampBelowTopStrip(
            float,
            strip: strip
        )
        #expect(clamped.minY == strip.maxY)
        #expect(clamped.size == float.size)
        // Already-clear frames pass through untouched.
        let clear = CGRect(
            x: 100,
            y: strip.maxY + 10,
            width: 400,
            height: 300
        )
        #expect(
            AppBarGeometry.clampBelowTopStrip(
                clear,
                strip: strip
            ) == clear
        )
    }
}
