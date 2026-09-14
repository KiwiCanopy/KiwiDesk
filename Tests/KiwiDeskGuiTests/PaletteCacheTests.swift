import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The one in-memory copy of `palettes.json` (#805):
/// `SettingsModel.userPalettes`, which the shelf draws and
/// search matches by name — `PaletteStore` stays stateless and
/// file-backed, and nothing on the search path reads it
/// (`SettingsSearchIndexTests ▸ matchPathStaysPure` holds the
/// match path; this suite holds the reader and the writers).
///
/// Main-actor spend (tests.md): three `makeTestModel` builds,
/// each writing one palette into its throwaway config directory.
@Suite("Palette cache", .serialized)
@MainActor
struct PaletteCacheTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    /// The whole route, from a saved file to a search row that
    /// lands on Colors.
    @Test("a saved palette is findable by name after a refresh")
    func refreshFeedsSearch() throws {
        pinEnglish()
        defer { reset() }
        let model = makeTestModel()
        #expect(model.userPalettes.isEmpty)
        try model.paletteStore.save(
            ColorPalette(name: "Sunset Desk", colors: [:])
        )
        model.refreshPalettes()
        #expect(model.userPalettes.map(\.name) == ["Sunset Desk"])

        let context = SettingsHeaderBar(model: model).searchContext
        #expect(context.palettes == ["Sunset Desk"])
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

    /// The header reads the CACHE, held by construction: a
    /// palette saved to disk without a refresh is invisible to
    /// the search context, so any reader that reached the store
    /// — the disk read per keystroke #805 draws the line at —
    /// would surface the name here. The negative needles beside
    /// it name the spellings such a reader would take.
    @Test("the search context never reads the store")
    func headerReadsTheCache() throws {
        pinEnglish()
        defer { reset() }
        let model = makeTestModel()
        try model.paletteStore.save(
            ColorPalette(name: "Night Shift", colors: [:])
        )
        #expect(
            SettingsHeaderBar(model: model).searchContext.palettes
                .isEmpty
        )
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings/")
        let header = SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "SettingsHeaderBar+Search.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(!header.isEmpty)
        for needle in [
            "paletteStore", "paletteLibrary", "userPalettes()",
            "libraryPalettes(", "refreshPalettes",
        ] {
            #expect(
                !header.contains(needle),
                Comment(rawValue: needle)
            )
        }
    }

    /// The two writers: the window's reload (the door a restored
    /// backup comes through), by behaviour; the shelf's one
    /// re-read after a mutation, by needle inside its body —
    /// the shelf is a view.
    @Test("the reload and the shelf write the cache")
    func writersAreWired() throws {
        pinEnglish()
        defer { reset() }
        let model = makeTestModel()
        try model.paletteStore.save(
            ColorPalette(name: "Night Shift", colors: [:])
        )
        model.reload()
        #expect(model.userPalettes.map(\.name) == ["Night Shift"])
        try model.paletteStore.delete("Night Shift")
        model.reload()
        #expect(model.userPalettes.isEmpty)

        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Colors/"
            )
        let shelf = SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "PaletteShelf+Actions.swift"
                ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        let mark = shelf.range(of: "funcreload()")
        var cursor =
            mark.map {
                shelf.distance(
                    from: shelf.startIndex,
                    to: $0.upperBound
                )
            } ?? 0
        let body =
            SourceScan.balanced(
                Array(shelf),
                from: &cursor,
                open: "{",
                close: "}"
            ) ?? ""
        #expect(!body.isEmpty)
        #expect(body.contains("model.refreshPalettes()"))
        // …and the shelf keeps no copy of its own.
        let view = SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "PaletteShelf.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(!view.contains("@State var userPalettes"))
    }
}
