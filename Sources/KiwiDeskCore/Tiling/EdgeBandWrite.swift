import ApplicationServices
import CoreGraphics

/// Which edges of `screen` refuse a small shrink (#2966).
struct EdgeBand: Equatable, Sendable {
    let screen: CGRect
    let bottom: Bool
    let right: Bool
}

/// A shrink near a screen's bottom or right edge, written from
/// clear of that edge (#2894). macOS refuses a small shrink of a
/// window whose bottom ends within ~19 pt of its screen's bottom,
/// or whose right side ends within ~16 pt of its screen's right,
/// while the app's `AXEnhancedUserInterface` is off, as KiwiDesk
/// holds it while writing (macOS 27, Firefox and Finder, measured
/// 2026-11-01/02). A resize keeps the top-left corner, so only
/// these two edges move. AX frames: y grows down.
///
/// A band exists only where another screen reaches past that edge
/// (#2966, table in the issue), anywhere along it: where along an
/// edge macOS refuses depends on the neighbours' extent, which no
/// gate here models. With "Displays have separate Spaces" on, the
/// bottom band was gone in one Finder run (2026-11-04); its control
/// with the setting off was Firefox. The right edge is not measured
/// there, so it keeps its band.
enum EdgeBandWrite {
    /// How far inside a screen's bottom or right edge a shrink is
    /// refused: measured ~19 pt, escaped from ~25 pt, set wider so
    /// a band that differs by setup still clears.
    static let band: CGFloat = 32

    /// The screens with a refusing edge, each naming which.
    static func bands(
        of screens: [CGRect],
        separateSpaces: Bool
    ) -> [EdgeBand] {
        screens.compactMap { screen in
            let bottom =
                !separateSpaces
                && screens.contains { $0.maxY > screen.maxY }
            let right = screens.contains { $0.maxX > screen.maxX }
            guard bottom || right else { return nil }
            return EdgeBand(screen: screen, bottom: bottom, right: right)
        }
    }

    /// The band whose refusing edge `frame` ends near, or nil.
    static func band(
        for frame: CGRect,
        among bands: [EdgeBand]
    ) -> EdgeBand? {
        bands.first { band in
            let screen = band.screen
            let bottom =
                band.bottom
                && frame.midX >= screen.minX && frame.midX < screen.maxX
                && ends(frame.maxY, near: screen.maxY)
            let right =
                band.right
                && frame.midY >= screen.minY && frame.midY < screen.maxY
                && ends(frame.maxX, near: screen.maxX)
            return bottom || right
        }
    }

    private static func ends(_ end: CGFloat, near edge: CGFloat) -> Bool {
        end > edge - band && end <= edge + band
    }

    /// Where to move the window before its size is written, with
    /// its `current` frame clear of `band` and on its screen; nil
    /// where no size write would be refused or no move clears it.
    /// A size write lands from the window's current corner, so an
    /// axis is refused only when that write ends in its band — a
    /// later frame of a long shrink, never its first — or when the
    /// window arrives from another screen. An axis that needs no
    /// move keeps its coordinate, or on an arrival takes the
    /// target's, either clamped so the current length is on the
    /// screen: a window hanging over onto a neighbouring screen
    /// takes no size write at all.
    static func liftedOrigin(
        target: CGRect,
        current: CGRect,
        band: EdgeBand
    ) -> CGPoint? {
        let screen = band.screen
        let arriving = !screen.contains(
            CGPoint(x: current.midX, y: current.midY)
        )
        let x =
            band.right
            ? clear(
                current.minX,
                current.width,
                to: target.minX,
                target.width,
                within: screen.minX,
                screen.maxX,
                arriving: arriving
            ) : nil
        let y =
            band.bottom
            ? clear(
                current.minY,
                current.height,
                to: target.minY,
                target.height,
                within: screen.minY,
                screen.maxY,
                arriving: arriving
            ) : nil
        guard x != nil || y != nil else { return nil }
        func kept(
            _ now: CGFloat,
            _ asked: CGFloat,
            _ length: CGFloat,
            _ low: CGFloat,
            _ high: CGFloat
        ) -> CGFloat {
            max(low, min(arriving ? asked : now, high - length))
        }
        return CGPoint(
            x: x
                ?? kept(
                    current.minX,
                    target.minX,
                    current.width,
                    screen.minX,
                    screen.maxX
                ),
            y: y
                ?? kept(
                    current.minY,
                    target.minY,
                    current.height,
                    screen.minY,
                    screen.maxY
                )
        )
    }

    /// One axis's start clear of the band at `high`, or nil where
    /// that axis needs no move or cannot clear.
    private static func clear(
        _ start: CGFloat,
        _ length: CGFloat,
        to asked: CGFloat,
        _ askedLength: CGFloat,
        within low: CGFloat,
        _ high: CGFloat,
        arriving: Bool
    ) -> CGFloat? {
        let edge = high - band
        let refused = start + length > edge && start + askedLength > edge
        guard askedLength < length, arriving || refused else { return nil }
        let clear = edge - length
        guard clear >= low else { return nil }
        return min(clear, asked)
    }

    /// The band a write merged over a waiting one carries: the
    /// newer frame's, else the waiting one's where the newer frame
    /// still ends in it, since the waiting write never ran.
    static func mergedBand(
        newer: EdgeBand?,
        waiting: EdgeBand?,
        frame: CGRect
    ) -> EdgeBand? {
        newer ?? waiting.flatMap { band(for: frame, among: [$0]) }
    }

    /// Writes `frame` through `writer`, moved first where `band`
    /// would refuse its size; runs on the app's frame queue. A nil
    /// `band` is the plain write.
    static func write(
        _ frame: CGRect,
        _ element: AXUIElement,
        nearEdgeOf band: EdgeBand?,
        writer: FrameWriter
    ) {
        lift(frame, element, nearEdgeOf: band, writer: writer)
        writer.setFrame(frame, element)
    }

    /// The move ahead of a size write, where one is owed.
    static func lift(
        _ frame: CGRect,
        _ element: AXUIElement,
        nearEdgeOf band: EdgeBand?,
        writer: FrameWriter
    ) {
        if let band,
            let current = writer.frame(element),
            let origin = liftedOrigin(
                target: frame,
                current: current,
                band: band
            )
        {
            writer.setPosition(origin, element)
        }
    }
}
