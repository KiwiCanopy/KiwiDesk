import AppKit
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `kiwidesk preview` (#1740 ▸ Preview): the KiwiDesk-Looks CI draws
/// each look's picture with it, so the file it writes must carry the
/// look on a dark desk, at one size, with the same bytes on every
/// run on one machine.
@Suite("CLI preview")
@MainActor
struct CLIPreviewTests {
    @Test("a look file becomes a fixed-size PNG in its own colors")
    func drawsTheLook() throws {
        let violet = try drawn(focused: "#564AB6")
        #expect(violet.width == 768 && violet.height == 480)
        #expect(Self.pixels(near: (0x56, 0x4A, 0xB6), in: violet) > 500)
        let amber = try drawn(focused: "#D79921")
        #expect(Self.pixels(near: (0x56, 0x4A, 0xB6), in: amber) == 0)
    }

    /// The ground is the look's own shelf colour a step darker
    /// over `SettingsTheme.lookGround` (#1740): 0x2E5A88 at 85 %
    /// over 0x0D0D12, read in a corner the focus haze misses. The
    /// retired neutral plate, `sunken`, draws nowhere.
    @Test("the ground is the look's own shelf colour")
    func groundIsTheShelf() throws {
        let image = try drawn(focused: "#564AB6", fill: "#2E5A88")
        #expect(Self.pixels(near: (0x29, 0x4E, 0x76), in: image) > 500)
        #expect(Self.pixels(near: (0x23, 0x2B, 0x26), in: image) == 0)
    }

    /// The card's own plate, scaled up: a taller plate is another
    /// layout, its bars a smaller share of the desk.
    @Test("the plate is the shelf card's, on four Spaces")
    func cardPlateOnFourSpaces() throws {
        #expect(
            CLIPreview.points.height == PaletteSceneThumbnail.baseHeight
        )
        let file = try Self.lookFile(focused: "#564AB6", in: Self.scratch())
        let look = try LookStore.importLook(data: Data(contentsOf: file))
        #expect(CLIPreview.desk(look).spaces.count == 4)
    }

    /// `runCLI` sends the verb here, not to the socket, which would
    /// write no file.
    @Test("runCLI dispatches preview")
    func dispatches() throws {
        let dir = try Self.scratch()
        let look = try Self.lookFile(focused: "#564AB6", in: dir)
        let out = dir.appendingPathComponent("out.png")
        #expect(runCLI(["kiwidesk", "preview", look.path, out.path]) == 0)
        #expect(FileManager.default.fileExists(atPath: out.path))
    }

    @Test("the same file draws the same bytes")
    func deterministic() throws {
        let dir = try Self.scratch()
        let look = try Self.lookFile(focused: "#564AB6", in: dir)
        let first = dir.appendingPathComponent("1.png")
        let second = dir.appendingPathComponent("2.png")
        #expect(Self.run(look, first) == 0)
        #expect(Self.run(look, second) == 0)
        #expect(try Data(contentsOf: first) == Data(contentsOf: second))
    }

    @Test("a file that is not a look, or a wrong call, writes nothing")
    func refuses() throws {
        let dir = try Self.scratch()
        let junk = dir.appendingPathComponent("junk.json")
        try Data("{\"name\": 1}".utf8).write(to: junk)
        let out = dir.appendingPathComponent("out.png")
        #expect(Self.run(junk, out) == 1)
        #expect(!FileManager.default.fileExists(atPath: out.path))
        #expect(CLIPreview.run(["kiwidesk", "preview"]) == 1)
    }

    private func drawn(
        focused: String,
        fill: String? = nil
    ) throws -> CGImage {
        let dir = try Self.scratch()
        let out = dir.appendingPathComponent("out.png")
        let look = try Self.lookFile(focused: focused, fill: fill, in: dir)
        try #require(Self.run(look, out) == 0)
        let source = try #require(
            CGImageSourceCreateWithURL(out as CFURL, nil)
        )
        return try #require(
            CGImageSourceCreateImageAtIndex(source, 0, nil)
        )
    }

    private static func run(_ look: URL, _ out: URL) -> Int32 {
        CLIPreview.run(["kiwidesk", "preview", look.path, out.path])
    }

    private static func scratch() throws -> URL {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    private static func lookFile(
        focused: String,
        fill: String? = nil,
        in dir: URL
    ) throws -> URL {
        let shelf = fill.map { ", \"kiwishelf.fill_color\": \"\($0)\"" }
        let json = """
            {"format": 2, "author": "Anna", "look": {"name": "Dusk",
             "style": {"border.sheen": 0},
             "colors": {"border.focused_color": "\(focused)"\(shelf ?? "")}}}
            """
        let url = dir.appendingPathComponent("look.json")
        try Data(json.utf8).write(to: url)
        return url
    }

    /// Pixels within 3 of `rgb` on every channel, read back in sRGB.
    private static func pixels(
        near rgb: (UInt8, UInt8, UInt8),
        in image: CGImage
    ) -> Int {
        let (w, h) = (image.width, image.height)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: w * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        let near = { (a: UInt8, b: UInt8) in abs(Int(a) - Int(b)) <= 3 }
        return stride(from: 0, to: bytes.count, by: 4).filter {
            near(bytes[$0], rgb.0) && near(bytes[$0 + 1], rgb.1)
                && near(bytes[$0 + 2], rgb.2)
        }.count
    }
}

/// The KiwiDesk-Looks repository's CI (`scripts/previews.py`) calls
/// the verb by name, probes for the usage line to tell a KiwiDesk
/// that has it, and the site sizes the card for the PNG. Like
/// `MCPInvocationContractTests`, a change that reds here breaks a
/// reader outside this repository and moves that reader with it.
@Suite("CLI preview contract")
struct CLIPreviewContractTests {
    @Test("the verb, its usage line and the PNG size are fixed")
    func contract() {
        #expect(CLIRoute.of("preview") == .preview)
        #expect(CLIPreview.usage.hasPrefix("usage: kiwidesk preview"))
        #expect(CLIPreview.pixels == CGSize(width: 768, height: 480))
    }
}
