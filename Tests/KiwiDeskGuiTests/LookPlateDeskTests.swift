import AppKit
import Foundation
import Testing
import UniformTypeIdentifiers

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

    /// Each id names an installed app and draws its own icon, never
    /// the generic one an unknown id or a lazy first draw gives.
    @Test("a look drawing icons takes each app's own icon")
    @MainActor
    func iconsAreTheApps() {
        let art = LookPlate.appArt(.appImage)
        let generic = NSWorkspace.shared.icon(for: .applicationBundle)
        #expect(art.count == LookPlate.apps.count)
        for (drawn, app) in zip(art, LookPlate.apps) {
            #expect(
                NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: app.bundleID
                ) != nil,
                "\(app.bundleID)"
            )
            guard case .icon(let image) = drawn else {
                Issue.record("\(app.bundleID) drew no icon")
                continue
            }
            #expect(Self.pixels(image) != Self.pixels(generic))
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
        let items = tile.appItems(settings.appBarLook(for: host))
        #expect(items.count == 3)
        #expect(items.allSatisfy { $0.art != nil && $0.label == nil })
        #expect(items.map(\.active) == [true, false, false])
    }

    /// The gallery's PNG is the one picture drawn at gallery size,
    /// the one standing the pocket; every card takes the tile. It
    /// matches a `size:` argument ending in `.gallery`, qualified or
    /// not; a size held in a variable is review's.
    @Test("only the gallery's picture is drawn at gallery size")
    func onlyThePreviewIsTheGallery() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var standing: [String] = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
                .filter { !$0.isWhitespace }
            let galleries = try NSRegularExpression(
                pattern: #"size:[A-Za-z.]*\.gallery"#
            ).numberOfMatches(
                in: source,
                range: NSRange(source.startIndex..., in: source)
            )
            if galleries > 0 {
                standing.append(file.lastPathComponent)
            }
        }
        #expect(standing == ["CLIPreview.swift"])
    }

    /// An art item measures what `pipBody` draws along the bar —
    /// the art and its padding — so the shelf's plan holds it
    /// (bars.md ▸ the end inset its layout adds).
    @Test("an art item's length is its art and padding")
    @MainActor
    func artLengthIsDrawn() throws {
        let settings = TilingSettings()
        let tile = HomeCardBarsTile(
            settings: settings,
            pocketStands: false,
            scale: 0.62,
            appArt: LookPlate.appArt(.appImage)
        )
        let host = try #require(settings.appBarHosts.first)
        let spec = tile.appSpec(
            settings.appBarLook(for: host),
            vertical: false
        )
        let pad = HomeCardBarsTile.pipPad.horizontal * 0.62
        #expect(
            spec.items.allSatisfy {
                abs($0.length - (spec.artSide + 2 * pad)) < 0.001
            }
        )
    }

    /// On an edge no bar shows, the gallery's pocket rests whole,
    /// kept on the plate at either end of its Position, as Core's
    /// handle band is (`ShelfMarkPlacement.bandStart`).
    @Test("the whole pocket stays on the plate at Position 0 and 100")
    @MainActor
    func wholePocketStaysOnThePlate() {
        var settings = TilingSettings()
        settings.kiwishelf.pocketEdge = .bottom
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        let plate = CGSize(width: 230, height: 144)
        for position: CGFloat in [0, 100] {
            settings.kiwishelf.pocketPosition = position
            let picture = LookPlate(
                settings: settings,
                spaceLabels: [],
                size: .gallery
            )
            #expect(picture.pocketRest == .mark)
            let side = PocketMarkGeometry.markSide(
                depth: picture.lonePocketDepth
            )
            let x = picture.lonePocketCentre(in: plate).x
            #expect(x >= side / 2 && x <= plate.width - side / 2)
        }
        #expect(
            LookPlate(settings: settings, spaceLabels: []).pocketRest == nil
        )
    }

    /// The gallery's pocket asks Core in the layout whose App Bar
    /// the picture draws, so on that bar's edge it is a section.
    @Test("a pocket on the App Bar's edge stands on its strip")
    @MainActor
    func pocketOnTheAppBarIsASection() {
        var settings = TilingSettings()
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.bottom)
        settings.kiwishelf.pocketEdge = .bottom
        let picture = LookPlate(
            settings: settings,
            spaceLabels: [],
            size: .gallery
        )
        #expect(picture.pocketRest == .section)
        #expect(picture.pocketReserve == nil)
    }

    /// `pipBody` pads with the one `pipPad` an art item's length
    /// reads, so the two cannot drift apart.
    @Test("pipBody pads with the shared pipPad")
    func pipBodyReadsThePad() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent("HomeCardPlate+BarStrip.swift")
        let source = try SourceScan.strippedSource(at: url)
            .filter { !$0.isWhitespace }
        #expect(!source.isEmpty)
        #expect(source.contains("HomeCardBarsTile.pipPad.horizontal*scale"))
        #expect(source.contains("HomeCardBarsTile.pipPad.vertical*scale"))
    }

    /// An image's pixels at a fixed 64 px square.
    private static func pixels(_ image: NSImage) -> Data? {
        var rect = CGRect(x: 0, y: 0, width: 64, height: 64)
        guard
            let cg = image.cgImage(
                forProposedRect: &rect,
                context: nil,
                hints: nil
            )
        else { return nil }
        return NSBitmapImageRep(cgImage: cg).tiffRepresentation
    }
}
