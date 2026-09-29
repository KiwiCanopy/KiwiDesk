import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The bundled looks (#1684): Glass derived from the starter for
/// the connected screens (#1739), bars included (#1528), every
/// look total over the register, each look's bars its
/// reference's, named palettes that exist, the ruled Sheen
/// column, and six tellable apart.
@Suite("Look catalog")
struct LookCatalogTests {
    private static let laptop = CGSize(width: 1512, height: 982)
    private static let desktop = CGSize(width: 2560, height: 1440)

    private var bundled: [ShelfLook] {
        LookCatalog.bundled(sizes: [Self.desktop])
    }

    /// The Starter profile a first run seeds for `sizes`.
    private func starter(_ sizes: [CGSize]) -> TilingSettings {
        StarterSetup.standardLayout(sizes: sizes).settings(sizes: sizes)
    }

    private func look(_ name: String) -> ShelfLook? {
        bundled.first { $0.name == name }
    }

    @Test("the six bundled looks, Glass first")
    func names() {
        #expect(
            bundled.map(\.name)
                == [
                    "Glass", "Taskbar", "Classic", "Tiler", "Pill",
                    "Sakura",
                ]
        )
    }

    @Test("Glass resets the shape to the starter's")
    func glassIsTheReset() throws {
        let glass = try #require(look(LookCatalog.defaultName))
        #expect(
            glass.colors == PaletteCatalog.defaultPalette().paintedColors
        )
        let first = starter([Self.desktop])
        var settings = first
        try #require(look("Tiler")).apply(to: &settings)
        #expect(!glass.isApplied(to: settings))
        glass.apply(to: &settings)
        #expect(
            LookKeys.extract(from: settings)
                == LookKeys.extract(from: first)
        )
    }

    /// The App Bar is the dock: a look splits the bars where its
    /// reference has one (owner, 2026-09-28, #1528).
    @Test("each look's bars sit where its reference's do")
    func barsFollowTheReference() throws {
        let edges: [String: (space: String, app: String)] = [
            "Glass": ("top", "bottom"), "Taskbar": ("bottom", "bottom"),
            "Classic": ("top", "top"), "Tiler": ("top", "top"),
            "Pill": ("top", "top"), "Sakura": ("top", "bottom"),
        ]
        for look in bundled {
            let want = try #require(edges[look.name], "\(look.name)")
            #expect(
                look.style["space_bar.edge"] == .string(want.space),
                "\(look.name)"
            )
            #expect(
                look.style["app_bar.edge"] == .string(want.app),
                "\(look.name)"
            )
        }
    }

    /// A Glass the starter's look keys disagree with moves a first
    /// run's windows (#1739) — its gaps then, its App Bar edge
    /// since #1528; the derivation itself is
    /// `LookCatalogSeamTests`'.
    @Test(
        "Glass is what a first run shows",
        arguments: [
            [laptop], [desktop], [laptop, desktop], [desktop, laptop],
        ]
    )
    @MainActor func glassIsTheFirstRun(sizes: [CGSize]) throws {
        let first = starter(sizes)
        let looks = LookCatalog.bundled(sizes: sizes)
        let glass = try #require(looks.first)
        #expect(glass.name == LookCatalog.defaultName)
        #expect(glass.isApplied(to: first))
        #expect(
            KiwiCore.painted(first, look: glass, palette: nil) == first
        )
        for other in looks.dropFirst() {
            #expect(!other.isApplied(to: first), "\(other.name)")
        }
    }

    /// Whatever look came before, a bundled look draws the same
    /// shelf: nothing of the previous one leaks through.
    @Test("a bundled look never inherits the previous look's styling")
    func bundledLooksAreTotal() {
        for look in bundled {
            var fresh = TilingSettings()
            look.apply(to: &fresh)
            for previous in bundled where previous.name != look.name {
                var settings = TilingSettings()
                previous.apply(to: &settings)
                look.apply(to: &settings)
                #expect(
                    LookKeys.extract(from: settings)
                        == LookKeys.extract(from: fresh),
                    "\(look.name) after \(previous.name)"
                )
            }
        }
    }

    /// A pairing no palette answers would fall back to the shipped
    /// colours silently (`AuthoredLook.colors(in:)`), so each must resolve —
    /// and a bundled look wears exactly its palette's colours
    /// (#1752).
    @Test("every bundled look wears a bundled palette's colours")
    func palettesExist() throws {
        let palettes = PaletteCatalog.bundled()
        for authored in LookCatalog.authored() {
            let palette = try #require(
                palettes.first { $0.name == authored.palette },
                "\(authored.name) names a palette nobody ships"
            )
            let look = try #require(
                bundled.first { $0.name == authored.name }
            )
            #expect(look.colors == palette.paintedColors, "\(look.name)")
        }
    }

    @Test("the Sheen column (ruling 2026-09-27)")
    func sheenColumn() throws {
        let column: [String: Double] = [
            "Glass": 0.5, "Taskbar": 0, "Classic": 0.25,
            "Tiler": 0, "Pill": 0.5, "Sakura": 0.6,
        ]
        for (name, sheen) in column {
            let look = try #require(look(name))
            var settings = TilingSettings()
            look.apply(to: &settings)
            #expect(Double(settings.borderStyle.sheen) == sheen, "\(name)")
        }
        #expect(
            Double(TilingSettings().borderStyle.sheen) == column["Glass"]
        )
    }

    @Test("every value survives its setter unchanged")
    func valuesAreLegal() {
        for look in bundled {
            var settings = TilingSettings()
            look.apply(to: &settings)
            let written = LookKeys.extract(from: settings)
            for (path, value) in look.style {
                #expect(
                    written[path] == value,
                    "\(look.name): \(path) was refused or clamped"
                )
            }
        }
    }

    /// Each pair differs on at least two of edge, fit, plain/boxed,
    /// glass, floating and a light or dark plate (issue draft).
    @Test("any two looks are told apart at a glance")
    func distinct() {
        // Where the bars sit is ONE axis: the pair of edges, so a
        // split and a fused shelf differ (#1731, #1528).
        let axes = [
            "kiwishelf.background_fit", "kiwishelf.background_style",
            "kiwishelf.liquid_glass", "kiwishelf.outer_margin",
        ]
        func edges(_ look: ShelfLook) -> [JSONValue?] {
            [look.style["space_bar.edge"], look.style["app_bar.edge"]]
        }
        for (i, a) in bundled.enumerated() {
            for b in bundled.dropFirst(i + 1) {
                let shape = axes.filter { a.style[$0] != b.style[$0] }
                let place = edges(a) != edges(b) ? 1 : 0
                let tone = isLight(a) != isLight(b) ? 1 : 0
                #expect(
                    shape.count + place + tone >= 2,
                    "\(a.name) vs \(b.name)"
                )
            }
        }
    }

    /// Whether the look's colours paint a light plate.
    private func isLight(_ look: ShelfLook) -> Bool {
        var settings = TilingSettings()
        look.apply(to: &settings)
        let hex = settings.kiwishelf.fillColor.dropFirst().prefix(6)
        let value = Int(hex, radix: 16) ?? 0
        let channels = [value >> 16, (value >> 8) & 0xFF, value & 0xFF]
        return channels.reduce(0, +) / 3 > 128
    }
}
