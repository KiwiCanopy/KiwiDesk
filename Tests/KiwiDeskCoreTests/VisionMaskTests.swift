import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The shape a KiwiVision plate draws (#2103 ruling 21): windows run
/// front to back, each one's visible part hazed or a hole, the
/// wallpaper hazed unless kept clear, in the plate's own coordinates.
@Suite("KiwiVision mask shape")
struct VisionMaskTests {
    private let screen = CGRect(x: 1000, y: 0, width: 800, height: 600)

    private func window(
        _ rect: CGRect,
        clear: Bool = false,
        radius: CGFloat = 16
    ) -> VisionMask.Window {
        VisionMask.Window(frame: rect, cornerRadius: radius, clear: clear)
    }

    private func shape(
        _ windows: [VisionMask.Window],
        clearWallpaper: Bool = true
    ) throws -> CGPath {
        try #require(
            VisionMask.path(
                screen: screen,
                clearWallpaper: clearWallpaper,
                windows: windows
            )
        )
    }

    @Test("a hazed wallpaper with no hole takes no mask")
    func wholeScreen() {
        #expect(
            VisionMask.path(
                screen: screen,
                clearWallpaper: false,
                windows: [
                    window(CGRect(x: 1100, y: 100, width: 200, height: 200))
                ]
            ) == nil
        )
    }

    @Test("a window draws in plate coordinates; the wallpaper does not")
    func windowsOnly() throws {
        let path = try shape([
            window(CGRect(x: 1100, y: 100, width: 200, height: 200))
        ])
        #expect(path.contains(CGPoint(x: 200, y: 200)))
        #expect(!path.contains(CGPoint(x: 500, y: 200)), "wallpaper")
        #expect(!path.contains(CGPoint(x: 1200, y: 200)), "unshifted")
    }

    @Test("windows union and leave their gap clear")
    func gapStaysClear() throws {
        let path = try shape([
            window(CGRect(x: 1100, y: 100, width: 100, height: 100)),
            window(CGRect(x: 1000, y: 0, width: 390, height: 600)),
            window(CGRect(x: 1410, y: 0, width: 390, height: 600)),
        ])
        #expect(path.contains(CGPoint(x: 150, y: 150)), "overlap draws")
        #expect(path.contains(CGPoint(x: 600, y: 300)))
        #expect(!path.contains(CGPoint(x: 400, y: 300)), "the gap")
    }

    @Test("corners follow each window's own radius")
    func roundedCorners() throws {
        let path = try shape([
            window(CGRect(x: 1100, y: 100, width: 200, height: 200)),
            window(
                CGRect(x: 1400, y: 100, width: 200, height: 200),
                radius: 40
            ),
        ])
        #expect(!path.contains(CGPoint(x: 101, y: 101)), "corner wedge")
        #expect(path.contains(CGPoint(x: 116, y: 116)))
        #expect(!path.contains(CGPoint(x: 408, y: 108)), "larger radius")
        #expect(path.contains(CGPoint(x: 440, y: 140)))
    }

    @Test("a clear window is a hole only where nothing covers it")
    func holeIsTheVisiblePart() throws {
        let front = CGRect(x: 1000, y: 0, width: 300, height: 600)
        let clear = CGRect(x: 1200, y: 100, width: 300, height: 300)
        let path = try shape(
            [window(front, radius: 0), window(clear, clear: true, radius: 0)],
            clearWallpaper: false
        )
        #expect(path.contains(CGPoint(x: 250, y: 200)), "covered part")
        #expect(!path.contains(CGPoint(x: 400, y: 200)), "visible part")
        #expect(path.contains(CGPoint(x: 700, y: 500)), "wallpaper")
    }

    @Test("a window behind a clear one is hazed only where seen")
    func behindAClearWindow() throws {
        let clear = CGRect(x: 1000, y: 0, width: 300, height: 600)
        let behind = CGRect(x: 1200, y: 100, width: 300, height: 300)
        let path = try shape([
            window(clear, clear: true, radius: 0),
            window(behind, radius: 0),
        ])
        #expect(!path.contains(CGPoint(x: 250, y: 200)), "under the hole")
        #expect(path.contains(CGPoint(x: 400, y: 200)))
    }

    /// With nothing clear the shape is the plain union, no boolean
    /// operation per pass; it covers what the walk would.
    @Test("no hole takes the plain union")
    func noHoleIsThePlainUnion() throws {
        let windows = [
            window(CGRect(x: 1100, y: 100, width: 200, height: 200)),
            window(CGRect(x: 1250, y: 150, width: 200, height: 200)),
        ]
        let path = try shape(windows)
        #expect(path.contains(CGPoint(x: 280, y: 180)), "the overlap")
        let walked = try shape(
            windows + [
                window(
                    CGRect(x: 1700, y: 500, width: 10, height: 10),
                    clear: true
                )
            ]
        )
        for point in [
            CGPoint(x: 280, y: 180), CGPoint(x: 150, y: 150),
            CGPoint(x: 600, y: 500),
        ] {
            #expect(path.contains(point) == walked.contains(point))
        }
    }

    /// Behind the last hole every window is hazed where seen, and
    /// a clear window covered by a hazed one in front stays hazed
    /// there: the walk that stops at the last hole loses nothing.
    @Test("windows behind the last hole stay hazed where seen")
    func walkStopsAtTheLastHole() throws {
        let front = CGRect(x: 1000, y: 0, width: 200, height: 600)
        let clear = CGRect(x: 1100, y: 100, width: 300, height: 300)
        let behind = CGRect(x: 1300, y: 200, width: 300, height: 300)
        for wallpaper in [true, false] {
            let path = try shape(
                [
                    window(front, radius: 0),
                    window(clear, clear: true, radius: 0),
                    window(behind, radius: 0),
                ],
                clearWallpaper: wallpaper
            )
            #expect(path.contains(CGPoint(x: 150, y: 200)), "front")
            #expect(!path.contains(CGPoint(x: 300, y: 200)), "the hole")
            #expect(
                !path.contains(CGPoint(x: 350, y: 300)),
                "behind, under the hole"
            )
            #expect(path.contains(CGPoint(x: 550, y: 450)), "behind")
            #expect(
                path.contains(CGPoint(x: 700, y: 550)) == !wallpaper,
                "the wallpaper"
            )
        }
    }

    @Test("a window on another screen draws nothing here")
    func otherScreenSkipped() throws {
        let path = try shape([
            window(CGRect(x: 0, y: 0, width: 400, height: 400))
        ])
        #expect(!path.contains(CGPoint(x: 100, y: 100)))
        #expect(path.boundingBoxOfPath.width < 1)
    }
}
