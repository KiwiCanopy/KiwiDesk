import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Monitors picture's geometry (#678 Phase 3, turn 13b).
///
/// Every assertion here reads a DERIVED rectangle, never a scan
/// for an input: a picture that takes the real frames and draws a
/// constant satisfies every substring a source scan can look for
/// while answering nothing (the `LayoutSchematicCountTests`
/// lesson). So the claims are arithmetic — this size, that
/// position, this ratio — and each one fails on the smallest edit
/// that breaks the promise it names.
@Suite("Monitor arrangement geometry")
struct MonitorArrangementTests {
    /// AppKit's global space: y grows UP, the main display's
    /// bottom-left is the origin.
    private func display(
        _ id: UInt32,
        _ name: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: name,
            frame: CGRect(x: x, y: y, width: width, height: height)
        )
    }

    private let canvas = CGSize(width: 700, height: 240)

    private func layout(
        _ displays: [Display],
        main: DisplayID? = nil,
        canvas: CGSize? = nil
    ) -> MonitorArrangement.Layout {
        MonitorArrangement.layout(
            displays: displays,
            mainID: main ?? displays.first?.id,
            canvas: canvas ?? self.canvas
        )
    }

    private func rect(
        _ result: MonitorArrangement.Layout,
        _ id: UInt32
    ) throws -> CGRect {
        try #require(
            result.displays.first { $0.id == DisplayID(id) }?.rect
        )
    }

    // MARK: - Points, never pixels

    /// The failure the digest names: a Retina display drawn twice
    /// the size of an identical non-Retina one. `Display.frame`
    /// is `NSScreen.frame`, which is already POINTS, and there is
    /// no backing-scale term anywhere in the arrangement — so two
    /// displays reporting the same point frame draw the same
    /// rectangle whatever their pixel density is.
    @Test("equal point frames draw equal rectangles")
    func pointsNotPixels() throws {
        let result = layout([
            display(1, "Retina", x: 0, y: 0, width: 1512, height: 982),
            display(
                2,
                "Not Retina",
                x: 1512,
                y: 0,
                width: 1512,
                height: 982
            ),
        ])
        #expect(try rect(result, 1).size == rect(result, 2).size)
    }

    /// …and the other half of the same rule: a display that is
    /// genuinely twice as many POINTS across draws twice as wide,
    /// so the picture is a scale drawing rather than a row of
    /// equal cards.
    @Test("twice the points draws twice the width")
    func sizeFollowsPoints() throws {
        let result = layout([
            display(1, "Laptop", x: 0, y: 0, width: 1000, height: 800),
            display(
                2,
                "Desk",
                x: 1000,
                y: 0,
                width: 2000,
                height: 1600
            ),
        ])
        let small = try rect(result, 1)
        let large = try rect(result, 2)
        #expect(abs(large.width - small.width * 2) < 0.001)
        #expect(abs(large.height - small.height * 2) < 0.001)
    }

    @Test("a portrait display draws portrait")
    func portraitDrawsPortrait() throws {
        let result = layout([
            display(1, "Desk", x: 0, y: 0, width: 2560, height: 1440),
            display(
                2,
                "Portrait",
                x: 2560,
                y: 0,
                width: 1440,
                height: 2560
            ),
        ])
        let portrait = try rect(result, 2)
        #expect(portrait.height > portrait.width)
        // Aspect preserved, not merely "taller than wide".
        #expect(
            abs(
                portrait.height / portrait.width - 2560 / 1440
            ) < 0.001
        )
    }

    // MARK: - Position

    /// AppKit's y grows up and the canvas's grows down, so a
    /// display sitting LOWER on the desk must draw lower on
    /// screen. Without the flip this reads upside down — the one
    /// error a user cannot talk themselves out of.
    @Test("a display below draws below")
    func belowDrawsBelow() throws {
        let result = layout([
            display(1, "Desk", x: 0, y: 0, width: 2560, height: 1440),
            display(
                2,
                "Laptop",
                x: 500,
                y: -982,
                width: 1512,
                height: 982
            ),
        ])
        #expect(try rect(result, 2).minY > rect(result, 1).minY)
    }

    @Test("a display to the right draws to the right")
    func rightDrawsRight() throws {
        let result = layout([
            display(1, "Left", x: 0, y: 0, width: 1000, height: 800),
            display(
                2,
                "Right",
                x: 1000,
                y: 0,
                width: 1000,
                height: 800
            ),
        ])
        #expect(try rect(result, 2).minX > rect(result, 1).minX)
    }

    /// Positions are laid out at ONE uniform scale, so the gap
    /// between two displays on the desk stays proportional to
    /// their size in the picture. A per-display position scale
    /// would tear the arrangement, which is the whole reason
    /// sizes come from points in the first place.
    @Test("the gap between displays scales with them")
    func gapsAreUniform() throws {
        let result = layout([
            display(1, "Left", x: 0, y: 0, width: 1000, height: 800),
            display(
                2,
                "Right",
                x: 1500,
                y: 0,
                width: 1000,
                height: 800
            ),
        ])
        let left = try rect(result, 1)
        let right = try rect(result, 2)
        let gap = right.minX - left.maxX
        // 500 pt of desk between two 1000 pt displays: half a
        // display wide, whatever the scale turns out to be.
        #expect(abs(gap - left.width / 2) < 0.001)
    }

}
