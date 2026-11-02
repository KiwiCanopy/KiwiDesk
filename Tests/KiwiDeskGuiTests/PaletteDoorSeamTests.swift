import Foundation
import Testing

/// The GUI reaches the palette library only through Core's doors
/// (#2875): no Settings file names the store's type or Core's
/// handle to it, so no alias can write past a door, and the shelf
/// reaches each write door from its own action.
@Suite("Palette door seam")
struct PaletteDoorSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let gui = root.appendingPathComponent(
        "Sources/KiwiDesk"
    )

    @Test("no GUI file holds the palette store")
    func guiNeverHoldsTheStore() throws {
        let files = try SourceScan.swiftSources(under: Self.gui)
        #expect(files.count > 100)
        for url in files {
            let source = try SourceScan.strippedSource(at: url)
            for token in ["PaletteStore", "paletteLibrary"] {
                #expect(
                    !source.contains(token),
                    "\(url.lastPathComponent) names \(token)"
                )
            }
        }
    }

    @Test("the shelf's actions reach every palette write door")
    func actionsTakeTheDoors() throws {
        let url = Self.gui.appendingPathComponent(
            "Settings/Components/Looks/PaletteShelf+Actions.swift"
        )
        let flat = try SourceScan.strippedSource(at: url)
            .split(whereSeparator: \.isWhitespace).joined()
        for door in [
            "core.savePalette(", "core.renamePalette(",
            "core.deletePalette(", "core.exportPalette(",
            "core.importPalette(",
        ] {
            #expect(flat.occurrences(of: door) == 1, "\(door)")
        }
    }
}
