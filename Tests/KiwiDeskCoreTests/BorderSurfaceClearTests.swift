import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The SkyLight ring surface is sized in whole points, so a
/// fractional overlay frame (a layout's split, an animation tick)
/// leaves a pixel row past the drawn bounds; a paint that clears
/// only those bounds leaves the row's stale content showing as a
/// straight line on the ring's edge (#1916).
@Suite("Border surface clear")
@MainActor
struct BorderSurfaceClearTests {
    @Test(
        "A fractional frame's whole-point edge row paints clear",
        arguments: [1, 2]
    )
    func fractionalEdgeRowIsCleared(scale: Int) throws {
        let geometry = BorderGeometry.compute(
            windowFrame: CGRect(x: 0, y: 0, width: 840, height: 491.5),
            width: 5,
            cornerStyle: .rounded,
            order: .above,
            systemRadius: 16,
            sheen: 0.6
        )
        // The surface WindowServer hands a 501.5 pt overlay: whole
        // points, at 1x and at the 2x the device captured.
        let width = Int(geometry.overlayFrame.width.rounded(.up)) * scale
        let height =
            Int(geometry.overlayFrame.height.rounded(.up)) * scale
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        // Stale content, the opaque white the device showed.
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

        SkyLightBorderOverlay.paint(
            geometry,
            colorHex: "#564AB6",
            into: context
        )

        // Bitmap row 0 is the surface's top, reaching past the
        // 501.5 pt the ring draws into. At 1x the stroke's outer
        // edge half-covers it, so ink there is the ring's own: the
        // defect is the stale white, and a lit corner, where the
        // rounded ring draws nothing.
        let data = try #require(context.data)
            .assumingMemoryBound(to: UInt8.self)
        let stale = (0..<width).filter { x in
            (0..<4).allSatisfy { data[x * 4 + $0] == 255 }
        }
        #expect(stale.isEmpty)
        let litCorner = (0..<(4 * scale)).filter { data[$0 * 4 + 3] != 0 }
        #expect(litCorner.isEmpty)
        // The ring itself drew: the top stroke spans 496.5–501.5 pt,
        // so 3 pt below the surface top is solid ink.
        let strokeRow = 3 * scale * width
        #expect(data[(strokeRow + width / 2) * 4 + 3] == 255)
    }
}
