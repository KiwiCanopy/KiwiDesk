import Foundation
import Testing

@testable import KiwiDeskCore

/// The bundled looks (#1684): Glass derived from the shipped
/// defaults, every look total over the register, named palettes
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

    @Test("Glass is the shipped defaults and resets the shape")
    func glassIsTheReset() throws {
        let glass = try #require(look(LookCatalog.defaultName))
        #expect(glass.palette == PaletteCatalog.defaultName)
        var settings = TilingSettings()
        try #require(look("Tiler")).apply(to: &settings)
        #expect(!glass.isApplied(to: settings))
        glass.apply(to: &settings)
        #expect(
            LookKeys.extract(from: settings)
                == LookKeys.extract(from: TilingSettings())
        )
    }

    @Test("every bundled look names the whole register")
    func bundledLooksAreTotal() {
        for look in bundled {
            #expect(
                Set(look.style.keys) == Set(LookKeys.all),
                "\(look.name) leaves styling to the previous look"
            )
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
        let axes = [
            "kiwishelf.edge", "kiwishelf.background_fit",
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
