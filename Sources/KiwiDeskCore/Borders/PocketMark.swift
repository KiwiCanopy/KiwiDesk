import AppKit

/// The pocket mark (#2446, design K5d): two kiwi slices in an open
/// pocket. Drawn as vectors on a 24-unit grid, so one image serves
/// the window mark, the Space Bar badge and KiwiHub's row at any
/// size; the kiwis keep their green whatever `ink` the pocket takes.
public enum PocketMark {
    /// The large mark: outlined slices and a dashed stitch.
    case mark
    /// The badge: solid shapes, no stitch, the pocket filled with
    /// `ink`.
    case badge

    static let kiwi = NSColor(
        srgbRed: 0.553,
        green: 0.702,
        blue: 0.329,
        alpha: 1
    )
    static let flesh = NSColor(
        srgbRed: 0.965,
        green: 0.949,
        blue: 0.816,
        alpha: 1
    )
    static let cloth = NSColor(
        srgbRed: 0.212,
        green: 0.212,
        blue: 0.235,
        alpha: 1
    )

    /// The mark at `size` points, its outlines (or, as a badge, its
    /// pocket) in `ink`.
    public func image(size: CGFloat, ink: NSColor) -> NSImage {
        NSImage(
            size: NSSize(width: size, height: size),
            flipped: true
        ) { rect in
            let scale = rect.width / 24
            let transform = AffineTransform(scale: scale)
            draw(ink: ink, transform: transform)
            return true
        }
    }

    private func draw(ink: NSColor, transform: AffineTransform) {
        for (x, y) in [(8.5, 6.8), (15.5, 5.3)] {
            let slice = Self.circle(x, y, 3.9)
            slice.transform(using: transform)
            Self.kiwi.setFill()
            slice.fill()
            if self == .mark {
                ink.setStroke()
                slice.lineWidth = 1.6 * transform.m11
                slice.stroke()
            }
            let core = Self.circle(x, y, self == .mark ? 1.48 : 1.56)
            core.transform(using: transform)
            Self.flesh.setFill()
            core.fill()
        }
        let pocket = Self.pocket(inset: 0, top: 9, bottom: 22.8, radius: 5)
        pocket.close()
        pocket.transform(using: transform)
        (self == .mark ? Self.cloth : ink).setFill()
        pocket.fill()
        (self == .mark ? ink : Self.cloth).setStroke()
        pocket.lineWidth = (self == .mark ? 2.2 : 1.6) * transform.m11
        pocket.lineJoinStyle = .round
        pocket.stroke()
        guard self == .mark else { return }
        let stitch = Self.pocket(
            inset: 2.4,
            top: 11.4,
            bottom: 20.4,
            radius: 2.6
        )
        stitch.transform(using: transform)
        ink.setStroke()
        stitch.lineWidth = 1.2 * transform.m11
        stitch.lineCapStyle = .round
        let dash = 1.6 * transform.m11
        stitch.setLineDash([dash, dash], count: 2, phase: 0)
        stitch.stroke()
    }

    private static func circle(
        _ x: CGFloat,
        _ y: CGFloat,
        _ r: CGFloat
    ) -> NSBezierPath {
        NSBezierPath(
            ovalIn: NSRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)
        )
    }

    /// The pocket's U, open at the top: sides `inset` in from the
    /// 4–20 body, rounded at the bottom.
    private static func pocket(
        inset: CGFloat,
        top: CGFloat,
        bottom: CGFloat,
        radius: CGFloat
    ) -> NSBezierPath {
        let left = 4 + inset
        let right = 20 - inset
        let path = NSBezierPath()
        path.move(to: NSPoint(x: left, y: top))
        path.line(to: NSPoint(x: left, y: bottom - radius))
        path.appendArc(
            from: NSPoint(x: left, y: bottom),
            to: NSPoint(x: left + radius, y: bottom),
            radius: radius
        )
        path.line(to: NSPoint(x: right - radius, y: bottom))
        path.appendArc(
            from: NSPoint(x: right, y: bottom),
            to: NSPoint(x: right, y: bottom - radius),
            radius: radius
        )
        path.line(to: NSPoint(x: right, y: top))
        return path
    }
}
