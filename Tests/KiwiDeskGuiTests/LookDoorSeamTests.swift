import Foundation
import Testing

/// The GUI reaches the look library only through Core's doors
/// (#2952), the palette doors' twin: no GUI file names Core's handle
/// to the store or the store itself, save the two spellings that
/// write nothing — its error cases a catch narrates and the
/// stateless parse of a look file's bytes.
@Suite("Look door seam")
struct LookDoorSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let gui = root.appendingPathComponent(
        "Sources/KiwiDesk"
    )
    /// Spellings of the store's type that hold no store.
    private static let readOnly = [
        "LookStore.StoreError", "LookStore.importLook(data:",
    ]

    @Test("no GUI file holds the look store")
    func guiNeverHoldsTheStore() throws {
        let files = try SourceScan.swiftSources(under: Self.gui)
        #expect(files.count > 100)
        for url in files {
            var source = try SourceScan.strippedSource(at: url)
            for spelling in Self.readOnly {
                source = source.replacingOccurrences(of: spelling, with: "")
            }
            for token in ["LookStore", "lookLibrary", "lookStore"] {
                #expect(
                    !source.contains(token),
                    "\(url.lastPathComponent) names \(token)"
                )
            }
        }
    }

    @Test("the shelf's actions reach every look write door")
    func actionsTakeTheDoors() throws {
        let doors = [
            "Settings/Components/Looks/LooksShelf+Actions.swift": [
                "core.saveLook(", "core.exportLook(", "core.importLook(",
            ],
            "Settings/SettingsModel+Look.swift": [
                "core.renameLook(", "core.deleteLook(",
            ],
        ]
        for (path, calls) in doors {
            let flat = try SourceScan.strippedSource(
                at: Self.gui.appendingPathComponent(path)
            ).split(whereSeparator: \.isWhitespace).joined()
            for door in calls {
                #expect(flat.occurrences(of: door) == 1, "\(door)")
            }
        }
    }
}
