import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The palette-name cache behind search's `.palette` kind
/// (#805): `PaletteStore` stays stateless and file-backed, so
/// the names search matches live on the model, written at the
/// store's mutation points and the window's reload — never
/// read lazily from the store, which is a disk read per
/// keystroke (`SettingsSearchIndexTests ▸ matchPathStaysPure`
/// holds the match path off the store).
///
/// Main-actor spend (tests.md): two `makeTestModel` builds, each
/// writing one palette into its throwaway config directory.
@Suite("Palette name cache", .serialized)
@MainActor
struct PaletteNameCacheTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    /// The cache reads the store on refresh and feeds a place
    /// result that lands on Colors — the whole route, from a
    /// saved file to a search row.
    @Test("a saved palette is findable by name after a refresh")
    func refreshFeedsSearch() throws {
        pinEnglish()
        defer { reset() }
        let model = makeTestModel()
        #expect(model.paletteNames.isEmpty)
        try model.paletteStore.save(
            ColorPalette(name: "Sunset Desk", colors: [:])
        )
        // Not yet: the cache is written at the mutation points,
        // never by the store.
        #expect(model.paletteNames.isEmpty)
        model.refreshPaletteNames()
        #expect(model.paletteNames == ["Sunset Desk"])

        var context = SettingsSearchContext()
        context.palettes = model.paletteNames
        let places = SettingsSearch.results(
            query: "sunset",
            context: context
        )
        .places
        #expect(places.count == 1)
        guard case .place(let place) = places.first else {
            Issue.record("no place row for the palette")
            return
        }
        #expect(place.kind == .palette)
        #expect(place.name == "Sunset Desk")
        #expect(place.anchor.destination == .colors)
        #expect(place.anchor.anchor == nil)
    }

    /// The window's reload is one of the cache's writers — the
    /// door a palette restored from a backup or saved elsewhere
    /// comes through.
    @Test("the model's reload refreshes the cache")
    func reloadRefreshes() throws {
        pinEnglish()
        defer { reset() }
        let model = makeTestModel()
        try model.paletteStore.save(
            ColorPalette(name: "Night Shift", colors: [:])
        )
        model.reload()
        #expect(model.paletteNames == ["Night Shift"])
        try model.paletteStore.delete("Night Shift")
        model.reload()
        #expect(model.paletteNames.isEmpty)
    }

    /// The other writer and the one reader, by needle: the
    /// shelf's one re-read after a mutation feeds the cache, and
    /// the header hands the cache — not the store — to search.
    /// A consult a behaviour test cannot see: the shelf is a
    /// view, and a reader that reached the store instead would
    /// pass every other clause while paying the disk read the
    /// cache exists to remove.
    @Test("the shelf writes the cache and the header reads it")
    func writerAndReaderAreWired() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings/")
        func squashed(_ path: String) throws -> String {
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(path),
                    encoding: .utf8
                )
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
        }
        let shelf = try squashed(
            "Components/Colors/PaletteShelf+Actions.swift"
        )
        #expect(
            shelf.contains(
                "funcreload(){userPalettes=store.userPalettes()"
                    + "model.refreshPaletteNames()}"
            )
        )
        let header = try squashed("SettingsHeaderBar+Search.swift")
        #expect(header.contains("palettes:model.paletteNames"))
        #expect(!header.contains("paletteStore"))
        #expect(!header.contains("userPalettes()"))
        let target = try squashed("SettingsModel+EditTarget.swift")
        #expect(
            target.contains(
                "refreshProfiles()refreshPaletteNames()"
            )
        )
    }
}
