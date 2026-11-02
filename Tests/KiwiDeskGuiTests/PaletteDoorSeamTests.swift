import Foundation
import Testing

/// The GUI writes the palette library only through Core's doors
/// (#2875): no Settings file calls a `PaletteStore` mutator, and
/// the shelf reaches each door from its own action.
@Suite("Palette door seam")
struct PaletteDoorSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let gui = root.appendingPathComponent(
        "Sources/KiwiDesk"
    )
    private static let mutators =
        "(save|delete|rename|export|importPalette|replaceUserPalettes)"

    /// `paletteStore` and `paletteLibrary` name the store anywhere;
    /// the shelf's own files also hold it as `store`.
    private func writes(in source: String, shelf: Bool) -> Int {
        let receiver =
            shelf
            ? "(paletteStore|paletteLibrary|\\bstore)"
            : "(paletteStore|paletteLibrary)"
        let pattern = receiver + "\\s*\\.\\s*" + Self.mutators + "\\s*\\("
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..., in: source)
        return regex?.numberOfMatches(in: source, range: range) ?? -1
    }

    @Test("no GUI file calls a palette store mutator")
    func noStoreWrites() throws {
        let files = try SourceScan.swiftSources(under: Self.gui)
        #expect(files.count > 100)
        var shelves = 0
        for url in files {
            let shelf = url.lastPathComponent.hasPrefix("PaletteShelf")
            if shelf { shelves += 1 }
            let source = try SourceScan.strippedSource(at: url)
            #expect(
                writes(in: source, shelf: shelf) == 0,
                "\(url.lastPathComponent) writes the palette store"
            )
        }
        #expect(shelves >= 2)
    }

    @Test("the shelf's actions reach every palette door")
    func actionsTakeTheDoors() throws {
        let url = Self.gui.appendingPathComponent(
            "Settings/Components/Looks/PaletteShelf+Actions.swift"
        )
        let flat = try SourceScan.strippedSource(at: url)
            .split(whereSeparator: \.isWhitespace).joined()
        for door in [
            "model.core.savePalette(", "model.core.renamePalette(",
            "model.core.deletePalette(", "model.core.exportPalette(",
            "model.core.importPalette(",
        ] {
            #expect(flat.occurrences(of: door) == 1, "\(door)")
        }
    }
}
