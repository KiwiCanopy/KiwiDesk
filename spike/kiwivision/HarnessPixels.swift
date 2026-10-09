// KiwiVision v0 probes (#2103) — pixel half of the harness: screen
// capture, edge energy, mean colour, PNG output, target windows.
// Capture shells out to /usr/sbin/screencapture: CGWindowListCreateImage
// is obsoleted in the macOS 15+ SDK. The HOST terminal needs Screen
// Recording; without it the capture is wallpaper-only and every metric
// lies, so `captureLooksReal` is checked once per probe.
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Capture

/// Captures `rect` (CG global points, top-left origin). The image is
/// in pixels (2x on Retina).
// UNVERIFIED: that `screencapture -R` takes global top-left POINTS on
// a multi-screen desk (single-screen it does).
func capture(rect: CGRect) -> CGImage? {
    let path = NSTemporaryDirectory() + "kv-cap-\(UUID().uuidString).png"
    defer { try? FileManager.default.removeItem(atPath: path) }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    p.arguments = [
        "-x", "-R",
        "\(Int(rect.minX)),\(Int(rect.minY)),"
            + "\(Int(rect.width)),\(Int(rect.height))",
        path,
    ]
    guard (try? p.run()) != nil else { return nil }
    p.waitUntilExit()
    // Read the bytes before the file goes: an image source decodes lazily.
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
        let src = CGImageSourceCreateWithData(data as CFData, nil)
    else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

/// Crops `img` (captured from `from`) to `sub`, both CG global points.
func crop(_ img: CGImage, from: CGRect, to sub: CGRect) -> CGImage? {
    let s = CGFloat(img.width) / from.width
    let r = CGRect(
        x: (sub.minX - from.minX) * s,
        y: (sub.minY - from.minY) * s,
        width: sub.width * s,
        height: sub.height * s
    ).integral
    return img.cropping(to: r)
}

/// Captures several regions from ONE screenshot of their union.
func captureRegions(_ regions: [CGRect]) -> [CGImage?] {
    guard let first = regions.first else { return [] }
    let union = regions.dropFirst().reduce(first) { $0.union($1) }
    guard let img = capture(rect: union) else {
        return regions.map { _ in nil }
    }
    return regions.map { crop(img, from: union, to: $0) }
}

// MARK: - Metrics

/// 8-bit grayscale pixels, row 0 at the top.
func grayPixels(_ img: CGImage) -> (w: Int, h: Int, px: [UInt8]) {
    let w = img.width
    let h = img.height
    var px = [UInt8](repeating: 0, count: w * h)
    px.withUnsafeMutableBytes { buf in
        let ctx = CGContext(
            data: buf.baseAddress,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        ctx?.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return (w, h, px)
}

/// Variance of the 4-neighbour Laplacian over grayscale: high for sharp
/// detail, near zero for a blurred or flat region.
func edgeEnergy(_ img: CGImage) -> Double {
    let (w, h, px) = grayPixels(img)
    guard w > 2, h > 2 else { return 0 }
    var sum = 0.0
    var sumSq = 0.0
    var n = 0.0
    for y in 1..<(h - 1) {
        for x in 1..<(w - 1) {
            let c = Double(px[y * w + x])
            let lap =
                Double(px[y * w + x - 1]) + Double(px[y * w + x + 1])
                + Double(px[(y - 1) * w + x]) + Double(px[(y + 1) * w + x])
                - 4 * c
            sum += lap
            sumSq += lap * lap
            n += 1
        }
    }
    let mean = sum / n
    return sumSq / n - mean * mean
}

struct RGB {
    let r: Double, g: Double, b: Double
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }
    func maxChannelDelta(_ o: RGB) -> Double {
        max(abs(r - o.r), abs(g - o.g), abs(b - o.b))
    }
    var text: String { "(\(Int(r)),\(Int(g)),\(Int(b)))" }
}

/// Mean sRGB colour, 0–255 per channel.
func meanRGB(_ img: CGImage) -> RGB {
    let w = img.width
    let h = img.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    px.withUnsafeMutableBytes { buf in
        let ctx = CGContext(
            data: buf.baseAddress,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        ctx?.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    var r = 0.0
    var g = 0.0
    var b = 0.0
    for i in stride(from: 0, to: px.count, by: 4) {
        r += Double(px[i])
        g += Double(px[i + 1])
        b += Double(px[i + 2])
    }
    let n = Double(w * h)
    return RGB(r: r / n, g: g / n, b: b / n)
}

/// A capture without Screen Recording shows no other app's windows
/// (wallpaper only). Heuristic: the region over a known textured
/// window must carry detail.
func captureLooksReal(_ img: CGImage?) -> Bool {
    guard let img else { return false }
    return edgeEnergy(img) > 20
}

// MARK: - Output

func writePNG(_ img: CGImage, _ url: URL) {
    guard
        let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else { return }
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

/// Downscales to `width` pixels wide, for contact-sheet thumbnails.
func scaled(_ img: CGImage, width: Int) -> CGImage? {
    let h = Int(Double(img.height) * Double(width) / Double(img.width))
    let ctx = CGContext(
        data: nil,
        width: width,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    ctx?.interpolationQuality = .high
    ctx?.draw(img, in: CGRect(x: 0, y: 0, width: width, height: h))
    return ctx?.makeImage()
}

// MARK: - Target windows

enum TargetPattern { case checkerboard, lineGrid, gradient }

/// Detail a blur must erase: a checkerboard with text, a 1-pt vertical
/// line grid over a gradient, or a photo-like gradient with discs.
final class PatternView: NSView {
    let pattern: TargetPattern

    init(frame: CGRect, pattern: TargetPattern) {
        self.pattern = pattern
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        switch pattern {
        case .checkerboard:
            let cell: CGFloat = 16
            NSColor.white.setFill()
            bounds.fill()
            NSColor.black.setFill()
            var y: CGFloat = 0
            while y < bounds.height {
                var x: CGFloat = Int(y / cell) % 2 == 0 ? 0 : cell
                while x < bounds.width {
                    CGRect(x: x, y: y, width: cell, height: cell).fill()
                    x += cell * 2
                }
                y += cell
            }
            drawText(color: .systemRed)
        case .lineGrid:
            drawGradient()
            NSColor.black.setFill()
            var x: CGFloat = 0
            while x < bounds.width {
                CGRect(x: x, y: 0, width: 1, height: bounds.height).fill()
                x += 12
            }
        case .gradient:
            drawGradient()
            for i in 0..<12 {
                let d = CGFloat(40 + i * 9)
                let rect = CGRect(
                    x: CGFloat(i) * 97 + 20,
                    y: CGFloat((i * 53) % 400) + 30,
                    width: d,
                    height: d
                )
                NSColor(
                    calibratedHue: CGFloat(i) / 12,
                    saturation: 0.8,
                    brightness: 0.9,
                    alpha: 1
                ).setFill()
                NSBezierPath(ovalIn: rect).fill()
            }
            drawText(color: .white)
        }
    }

    private func drawGradient() {
        NSGradient(colors: [
            .systemOrange, .systemPink, .systemBlue,
            .systemTeal, .systemGreen,
        ])?
        .draw(in: bounds, angle: 30)
    }

    private func drawText(color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: color,
        ]
        var y: CGFloat = 10
        while y < bounds.height {
            ("KiwiVision probe — the quick brown fox 0123456789" as NSString)
                .draw(at: CGPoint(x: 10, y: y), withAttributes: attrs)
            y += 64
        }
    }
}

/// A titled target window, ordered front. `frame` is AppKit coordinates.
@MainActor
func makeTarget(frame: CGRect, pattern: TargetPattern, title: String)
    -> NSWindow
{
    let w = NSWindow(
        contentRect: frame,
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    w.title = title
    w.isReleasedWhenClosed = false
    w.contentView = PatternView(
        frame: CGRect(origin: .zero, size: frame.size),
        pattern: pattern
    )
    w.orderFrontRegardless()
    return w
}
