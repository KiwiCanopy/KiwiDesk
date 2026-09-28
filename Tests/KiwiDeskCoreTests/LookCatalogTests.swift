import Foundation
import Testing

@testable import KiwiDeskCore

/// The bundled looks (#1684): Glass derived from the shipped
/// defaults and the starter's bars, every look total over the
/// register, each look's bars its reference's, named palettes
/// that exist, the ruled Sheen column, and five tellable apart.
@Suite("Look catalog")
struct LookCatalogTests {
    private var bundled: [ShelfLook] { LookCatalog.bundled() }

    private func look(_ name: String) -> ShelfLook? {
        bundled.first { $0.name == name }
    }

    @Test("the five bundled looks, Glass first")
    func names() {
        #expect(
            bundled.map(\.name)
                == ["Glass", "Taskbar", "Classic", "Tiler", "Pill"]
        )
    }

    /// Read off the composed starter, not the constant, so Glass
    /// and the first-run picture cannot part (#1528).
    @Test("Glass is the shipped defaults with the starter's bars")
    func glassIsTheStartersLook() throws {
        let glass = try #require(look(LookCatalog.defaultName))
        #expect(glass.palette == PaletteCatalog.defaultName)
        let laptop = CGSize(width: 1728, height: 1117)
        var starter = TilingSettings()
        starter.appBarStyle.edge =
            StarterSetup.settings(sizes: [laptop]).appBarStyle.edge
        var settings = TilingSettings()
        try #require(look("Tiler")).apply(to: &settings)
        #expect(!glass.isApplied(to: settings))
        glass.apply(to: &settings)
        #expect(
            LookKeys.extract(from: settings)
                == LookKeys.extract(from: starter)
        )
    }

    /// The App Bar is the dock: a look splits the bars where its
    /// reference has one (owner, 2026-09-28, #1528).
    @Test("each look's bars sit where its reference's do")
    func barsFollowTheReference() throws {
        let edges: [String: (space: String, app: String)] = [
            "Glass": ("top", "bottom"), "Taskbar": ("bottom", "bottom"),
            "Classic": ("top", "top"), "Tiler": ("top", "top"),
            "Pill": ("top", "top"),
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

    @Test("every bundled look names a bundled palette")
    func palettesExist() {
        let names = Set(PaletteCatalog.bundled().map(\.name))
        for look in bundled {
            #expect(
                look.palette.map(names.contains) == true,
                "\(look.name) names a palette nobody ships"
            )
        }
    }

    @Test("the Sheen column (ruling 2026-09-27)")
    func sheenColumn() throws {
        let column: [String: Double] = [
            "Glass": 0.5, "Taskbar": 0, "Classic": 0.25,
            "Tiler": 0, "Pill": 0.5,
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
        // The Space Bar's edge stands for where the bars sit: one
        // axis, however the two edges pair (#1731).
        let axes = [
            "space_bar.edge", "kiwishelf.background_fit",
            "kiwishelf.background_style", "kiwishelf.liquid_glass",
            "kiwishelf.outer_margin",
        ]
        for (i, a) in bundled.enumerated() {
            for b in bundled.dropFirst(i + 1) {
                let shape = axes.filter { a.style[$0] != b.style[$0] }
                let tone = isLight(a) != isLight(b) ? 1 : 0
                #expect(
                    shape.count + tone >= 2,
                    "\(a.name) vs \(b.name)"
                )
            }
        }
    }

    /// Whether the look's palette paints a light plate.
    private func isLight(_ look: ShelfLook) -> Bool {
        var settings = TilingSettings()
        let palette = PaletteCatalog.bundled().first {
            $0.name == look.palette
        }
        palette?.apply(to: &settings)
        let hex = settings.kiwishelf.fillColor.dropFirst().prefix(6)
        let value = Int(hex, radix: 16) ?? 0
        let channels = [value >> 16, (value >> 8) & 0xFF, value & 0xFF]
        return channels.reduce(0, +) / 3 > 128
    }
}
