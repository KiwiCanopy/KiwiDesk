import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pictures looks carry (#3478 ▸ Library): copied in under their
/// content hash, refused when ImageIO reads no picture.
@Suite("Wallpaper library")
struct WallpaperLibraryTests {
    static func png(_ side: Int = 8) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        return rep.representation(using: .png, properties: [:])!
    }

    private func library() -> WallpaperLibrary {
        WallpaperLibrary(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(UUID().uuidString)
        )
    }

    @Test("a picture is stored under its hash")
    func addsByHash() throws {
        let library = library()
        let data = Self.png()
        let name = try library.add(data)
        #expect(LookWallpaper.isLibraryName(name))
        #expect(name.hasSuffix(".png"))
        #expect(library.data(of: name) == data)
        #expect(try library.add(data) == name)
        #expect(library.names() == [name])
    }

    @Test("bytes that are no picture are refused")
    func refusesText() {
        #expect(throws: WallpaperLibrary.Refusal.notAPicture) {
            try library().add(Data("hello".utf8))
        }
    }

    @Test("a shrink keeps the format and fits the size")
    func shrink() throws {
        let data = Self.png(64)
        let small = try #require(WallpaperShrink.shrunk(data, maxPixels: 16))
        #expect(WallpaperLibrary.fileExtension(of: small) == "png")
        let image = try #require(NSBitmapImageRep(data: small))
        #expect(max(image.pixelsWide, image.pixelsHigh) <= 16)
    }
}
