import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The shape a KiwiVision plate draws (#2103 ruling 21): the whole
/// screen while the wallpaper is hazed, else only the windows, in
/// the plate's own coordinates, rounded at the window radius.
@Suite("KiwiVision mask shape")
struct VisionMaskTests {
    private let screen = CGRect(x: 1000, y: 0, width: 800, height: 600)

    private func shape(_ windows: [CGRect]) throws -> CGPath {
        try #require(
            VisionMask.path(
                screen: screen,
                clearWallpaper: true,
                windows: windows,
                cornerRadius: 16
            )
        )
    }

    @Test("the hazed wallpaper takes no mask")
    func wholeScreen() {
        #expect(
            VisionMask.path(
                screen: screen,
                clearWallpaper: false,
                windows: [CGRect(x: 1100, y: 100, width: 200, height: 200)],
                cornerRadius: 16
            ) == nil
        )
    }

    @Test("a window draws in plate coordinates; the wallpaper does not")
    func windowsOnly() throws {
        let path = try shape([
            CGRect(x: 1100, y: 100, width: 200, height: 200)
        ])
        #expect(path.contains(CGPoint(x: 200, y: 200)))
        #expect(!path.contains(CGPoint(x: 500, y: 200)), "wallpaper")
        #expect(!path.contains(CGPoint(x: 1200, y: 200)), "global, unshifted")
    }

    @Test("two windows union and leave their gap clear")
    func gapStaysClear() throws {
        let path = try shape([
            CGRect(x: 1000, y: 0, width: 390, height: 600),
            CGRect(x: 1410, y: 0, width: 390, height: 600),
            // Overlapping the first: the non-zero fill unions it.
            CGRect(x: 1100, y: 100, width: 100, height: 100),
        ])
        #expect(path.contains(CGPoint(x: 150, y: 150)), "overlap draws")
        #expect(path.contains(CGPoint(x: 600, y: 300)))
        #expect(!path.contains(CGPoint(x: 400, y: 300)), "the gap")
    }

    @Test("corners follow the window radius")
    func roundedCorners() throws {
        let path = try shape([
            CGRect(x: 1100, y: 100, width: 200, height: 200)
        ])
        #expect(!path.contains(CGPoint(x: 101, y: 101)), "corner wedge")
        #expect(path.contains(CGPoint(x: 116, y: 116)))
    }

    @Test("a window on another screen draws nothing here")
    func otherScreenSkipped() throws {
        let path = try shape([CGRect(x: 0, y: 0, width: 400, height: 400)])
        #expect(path.isEmpty)
    }
}
