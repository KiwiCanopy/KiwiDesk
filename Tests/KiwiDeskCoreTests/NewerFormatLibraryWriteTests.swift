import Foundation
import Testing

@testable import KiwiDeskCore

/// The palette and look libraries refuse to write over a file a
/// newer build wrote (#2325): every mutating write decodes the
/// library first, and that decode refuses a newer format. The
/// behavioural half of `ConfigWriterCensusTests`' entries for the
/// two stores; each fixture differs from a current file by its
/// format alone.
@Suite("Newer-format library writes (#2324)")
@MainActor
struct NewerFormatLibraryWriteTests {
    private func scratch() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-libs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    /// Re-stamps `file`'s top-level `format`.
    private func restamp(_ file: URL, to format: Int) throws {
        var root = try #require(
            try JSONSerialization.jsonObject(
                with: Data(contentsOf: file)
            ) as? [String: Any]
        )
        root["format"] = format
        try JSONSerialization.data(withJSONObject: root)
            .write(to: file)
    }

    @Test("A newer palette library is never rewritten")
    func paletteLibraryKept() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PaletteStore(directory: dir)
        let palette = ColorPalette(name: "Mine", colors: [:])
        try store.save(palette)
        try store.save(ColorPalette(name: "Other", colors: [:]))
        try restamp(store.url, to: PaletteDocument.currentFormat + 1)
        let before = try Data(contentsOf: store.url)
        #expect(throws: (any Error).self) {
            try store.save(ColorPalette(name: "New", colors: [:]))
        }
        #expect(throws: (any Error).self) { try store.delete("Mine") }
        #expect(throws: (any Error).self) {
            try store.rename(from: "Mine", to: "Renamed")
        }
        #expect(try Data(contentsOf: store.url) == before)
    }

    @Test("A newer look library is never rewritten")
    func lookLibraryKept() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LookStore(directory: dir)
        func look(_ name: String) -> ShelfLook {
            ShelfLook(name: name, style: [:], colors: [:])
        }
        try store.save(look("Mine"))
        try store.save(look("Other"))
        try restamp(store.url, to: LookDocument.currentFormat + 1)
        let before = try Data(contentsOf: store.url)
        #expect(throws: (any Error).self) { try store.save(look("New")) }
        #expect(throws: (any Error).self) { try store.delete("Mine") }
        #expect(throws: (any Error).self) {
            try store.rename(from: "Mine", to: "Renamed")
        }
        #expect(try Data(contentsOf: store.url) == before)
    }
}
