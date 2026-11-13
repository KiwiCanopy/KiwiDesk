import AppKit
import SwiftUI

/// The glyphs SF Symbols has no good answer for (#3281, owner-picked):
/// drawn as vector paths into template images on a 20 pt grid, so
/// they scale and tint like a symbol, though they keep one stroke
/// weight. Named `kiwi.*` so a symbol slot can carry either kind;
/// `GlyphImage` draws both.
enum CustomGlyph: Hashable {
    case click, rightClick, wheelClick, sideButtons
    case taps(Int)
    case swipes(Int)
    /// The window list walked: three windows in a row over an arrow.
    case walk

    static let prefix = "kiwi."

    var name: String {
        switch self {
        case .click: "kiwi.click"
        case .rightClick: "kiwi.right_click"
        case .wheelClick: "kiwi.wheel_click"
        case .sideButtons: "kiwi.side_buttons"
        case .taps(let n): "kiwi.taps.\(n)"
        case .swipes(let n): "kiwi.swipes.\(n)"
        case .walk: "kiwi.walk"
        }
    }

    init?(name: String) {
        let all: [CustomGlyph] =
            [.click, .rightClick, .wheelClick, .sideButtons, .walk]
            + (2...5).flatMap { [CustomGlyph.taps($0), .swipes($0)] }
        guard let glyph = all.first(where: { $0.name == name }) else {
            return nil
        }
        self = glyph
    }

    /// The glyph as a template image, one per glyph for the process.
    @MainActor var image: NSImage {
        if let cached = Self.cache[self] { return cached }
        let image = NSImage(
            size: NSSize(width: 20, height: 20),
            flipped: true
        ) { _ in
            NSColor.black.set()
            draw()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = nil
        Self.cache[self] = image
        return image
    }

    @MainActor private static var cache: [CustomGlyph: NSImage] = [:]

    // MARK: - Drawing, on a 20 × 20 grid, y down

    private func draw() {
        switch self {
        case .click, .rightClick, .wheelClick, .sideButtons:
            Self.mouse()
            mouseKey()
        case .taps(let n): Self.tapDots(n)
        case .swipes(let n): Self.swipeDots(n)
        case .walk: Self.windowRow()
        }
    }

    private static func stroke(_ path: NSBezierPath, _ width: CGFloat = 1.5) {
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private static func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        NSBezierPath(
            ovalIn: NSRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)
        ).fill()
    }

    private static func line(_ a: NSPoint, _ b: NSPoint, _ width: CGFloat) {
        let path = NSBezierPath()
        path.move(to: a)
        path.line(to: b)
        stroke(path, width)
    }

    /// A line from `a` to `b` with an open head at `b`.
    private static func arrow(_ a: NSPoint, _ b: NSPoint) {
        line(a, b, 1.5)
        let angle = atan2(b.y - a.y, b.x - a.x)
        let head = NSBezierPath()
        for side in [-CGFloat.pi / 5, .pi / 5] {
            head.move(to: b)
            head.line(
                to: NSPoint(
                    x: b.x - 3.4 * cos(angle + side),
                    y: b.y - 3.4 * sin(angle + side)
                )
            )
        }
        stroke(head)
    }

    private static let outline = NSRect(x: 5, y: 1.5, width: 10, height: 17)

    /// The mouse's outline, its key split and its key line.
    private static func mouse() {
        stroke(NSBezierPath(roundedRect: outline, xRadius: 5, yRadius: 5))
        line(NSPoint(x: 10, y: 1.8), NSPoint(x: 10, y: 6.5), 1.1)
        line(NSPoint(x: 5.3, y: 7.5), NSPoint(x: 14.7, y: 7.5), 1.1)
    }

    /// The one part of the mouse a button glyph fills.
    private func mouseKey() {
        switch self {
        case .click: Self.key(from: 5)
        case .rightClick: Self.key(from: 10)
        case .wheelClick:
            Self.pill(NSRect(x: 8.4, y: 2.8, width: 3.2, height: 3.6))
        case .sideButtons:
            Self.pill(NSRect(x: 1.6, y: 6.4, width: 2.4, height: 3.4))
            Self.pill(NSRect(x: 1.6, y: 10.8, width: 2.4, height: 3.4))
        default: break
        }
    }

    /// A whole key, filled: the outline's area between its edge, the
    /// split and the key line, from `x` five points across (#3281,
    /// owner).
    private static func key(from x: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(
            roundedRect: outline,
            xRadius: 5,
            yRadius: 5
        ).addClip()
        NSRect(x: x, y: outline.minY, width: 5, height: 6).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func pill(_ rect: NSRect) {
        let r = min(rect.width, rect.height) / 2
        NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
    }

    /// `n` finger dots on an arc.
    private static func tapDots(_ n: Int) {
        let points: [NSPoint] =
            switch n {
            case 2: [NSPoint(x: 6.5, y: 10), NSPoint(x: 13.5, y: 10)]
            case 3:
                [
                    NSPoint(x: 4.5, y: 11), NSPoint(x: 10, y: 8),
                    NSPoint(x: 15.5, y: 11),
                ]
            case 4:
                [
                    NSPoint(x: 3.5, y: 12), NSPoint(x: 7.8, y: 8),
                    NSPoint(x: 12.2, y: 8), NSPoint(x: 16.5, y: 12),
                ]
            default:
                [
                    NSPoint(x: 2.5, y: 13), NSPoint(x: 6, y: 8.5),
                    NSPoint(x: 10, y: 7), NSPoint(x: 14, y: 8.5),
                    NSPoint(x: 17.5, y: 13),
                ]
            }
        // Close dots stay apart: smaller as the count grows.
        let r: CGFloat = n > 4 ? 1.6 : n > 3 ? 1.9 : 2.2
        for point in points { dot(point.x, point.y, r) }
    }

    /// `n` finger dots stacked, moving right.
    private static func swipeDots(_ n: Int) {
        let ys: [CGFloat] =
            switch n {
            case 2: [7, 13]
            case 3: [5, 10, 15]
            case 4: [4, 8, 12, 16]
            default: [3, 6.5, 10, 13.5, 17]
            }
        for y in ys { dot(5, y, n > 4 ? 1.25 : n > 3 ? 1.6 : 1.9) }
        arrow(NSPoint(x: 9.5, y: 10), NSPoint(x: 18, y: 10))
    }

    private static func windowRow() {
        for x: CGFloat in [1.5, 7.5, 13.5] {
            stroke(
                NSBezierPath(
                    roundedRect: NSRect(x: x, y: 3.5, width: 5, height: 7),
                    xRadius: 1.2,
                    yRadius: 1.2
                ),
                1.2
            )
        }
        arrow(NSPoint(x: 3, y: 15.5), NSPoint(x: 17, y: 15.5))
    }
}

/// A symbol slot's image: a `kiwi.*` custom glyph, else the SF
/// Symbol of that name.
struct GlyphImage: View {
    let name: String

    init(_ name: String) { self.name = name }

    var body: some View {
        if let glyph = CustomGlyph(name: name) {
            Image(nsImage: glyph.image).renderingMode(.template)
        } else {
            Image(systemName: name)
        }
    }
}
