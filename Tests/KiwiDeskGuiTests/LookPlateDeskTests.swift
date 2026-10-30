import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A look's picture is a desk in the look (#1740): its App Bar
/// shows Finder, Safari and Mail as the look draws apps, and only
/// the gallery's picture stands the pocket. The source scan runs
/// off the main actor; the rest reads views and spends little.
struct LookPlateDeskTests {
    /// The App Font draws a ligature, so each must be the font's
    /// own name for its app, read from the bundled map, or the
    /// picture draws the ligature's letters.
    @Test("a look drawing symbols takes each app's App Font glyph")
    @MainActor
    func symbolsAreTheFontsOwn() throws {
        let map = try #require(AppFontGlyphMap.loadBundled())
        let names = ["Finder", "Safari", "Mail"]
        let art = LookPlate.appArt(.appFont)
        #expect(art.count == names.count)
        for (drawn, name) in zip(art, names) {
            guard case .appFont(let ligature) = drawn else {
                Issue.record("\(name) drew no App Font glyph")
                continue
            }
            #expect(ligature == map.ligature(for: name))
        }
    }

    @Test("a look drawing icons takes each app's own icon")
    @MainActor
    func iconsAreTheApps() {
        let art = LookPlate.appArt(.appImage)
        #expect(art.count == 3)
        for drawn in art {
            guard case .icon = drawn else {
                Issue.record("an app drew no icon")
                continue
            }
        }
    }

    /// The App Bar's items carry the art, the first the active one,
    /// with no title: a look's picture has no room for one.
    @Test("the App Bar draws the art, the first app active")
    @MainActor
    func appBarTakesTheArt() throws {
        let settings = TilingSettings()
        let tile = HomeCardBarsTile(
            settings: settings,
            pocketStands: false,
            appArt: LookPlate.appArt(.appFont)
        )
        let host = try #require(settings.appBarHosts.first)
        let items = tile.appItems(
            settings.appBarLook(for: host),
            vertical: false
        )
        #expect(items.count == 3)
        #expect(items.allSatisfy { $0.art != nil && $0.label == nil })
        #expect(items.map(\.active) == [true, false, false])
    }

    /// The gallery's PNG is the one picture drawn at gallery size,
    /// the one standing the pocket; every card takes the tile.
    @Test("only the gallery's picture is drawn at gallery size")
    func onlyThePreviewIsTheGallery() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var standing: [String] = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
                .filter { !$0.isWhitespace }
            if source.contains("size:.gallery") {
                standing.append(file.lastPathComponent)
            }
        }
        #expect(standing == ["CLIPreview.swift"])
    }
}
