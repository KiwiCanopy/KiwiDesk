import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// Every update window's footer sits on the window's glass: it
/// paints no ground of its own, only its hairline (#3111).
@MainActor
@Suite("Update footer on glass (#3111)")
struct UpdateFooterGlassTests {
    private static let width: CGFloat = 400
    /// Rendered at an explicit 2x (pixel probes, tests.md).
    private static let scale: CGFloat = 2

    private static func footers() -> [(String, AnyView)] {
        [
            ("What's new / Up to date", AnyView(WhatsNewFooter {})),
            (
                "offer",
                AnyView(UpdateWindowFooter(session: UpdateSession { _ in }))
            ),
            ("checking", AnyView(UpdateCheckingFooter {})),
        ]
    }

    /// The corner inside the bar's padding, clear of every label
    /// and button, is transparent — the glass shows through — while
    /// the hairline above it still draws.
    @Test(
        "the footer paints only its hairline",
        arguments: [ColorScheme.light, .dark]
    )
    func paintsNoGround(scheme: ColorScheme) throws {
        LocalizationManager.shared.select("en")
        for (name, footer) in Self.footers() {
            let pixels = try Self.alpha(
                footer.environment(\.colorScheme, scheme)
            )
            let rows = pixels.count
            // Bottom 8 pt, left 12 pt: inside the 14 pt vertical
            // and 16 pt horizontal padding.
            let band = Int(8 * Self.scale)
            let inset = Int(12 * Self.scale)
            let painted = pixels[(rows - band)...]
                .flatMap { $0[..<inset] }
                .filter { $0 > 0 }
                .count
            #expect(painted == 0, "\(name) paints a ground: \(painted)")
            let hairline = pixels[0][..<inset].filter { $0 > 0 }.count
            #expect(hairline == inset, "\(name) lost its hairline")
        }
    }

    /// Alpha per pixel, top row first.
    private static func alpha(_ view: some View) throws -> [[UInt8]] {
        let renderer = ImageRenderer(
            content: LocaleScopedRoot { view.frame(width: width) }
                .environmentObject(LocalizationManager.shared)
        )
        renderer.scale = scale
        let image = try #require(renderer.cgImage)
        let (w, h) = (image.width, image.height)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: w,
                    height: h,
                    bitsPerComponent: 8,
                    bytesPerRow: w * 4,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        try #require(drawn)
        return (0..<h).map { row in
            (0..<w).map { bytes[(row * w + $0) * 4 + 3] }
        }
    }
}
