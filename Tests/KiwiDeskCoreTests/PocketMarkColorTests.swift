import AppKit
import Testing

@testable import KiwiDeskCore

/// The pocket mark's own colour (#2671): `pocket.set_color`, the
/// window mark's glyph and the Space Bar badge carrying it, the
/// pocket drawn opaque in it, and kiwi green against the plate's
/// lightest and darkest mark ink.
@Suite("Pocket mark color", .serialized)
@MainActor
struct PocketMarkColorTests {
    private let amber = "#E8A33D"

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-pocket-color-\(UUID().uuidString)"
                )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 900_101,
                    appName: "App",
                    title: "Doc",
                    frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                )
            )
        )
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

    /// The pixel at grid point `at` of `image` drawn at 2x; the
    /// default (12, 15) is inside the pocket, clear of the kiwis
    /// and the stitch.
    private func pocketPixel(
        _ image: NSImage,
        appearance: NSAppearance.Name = .aqua,
        at point: (x: Int, y: Int) = (12, 15)
    ) throws -> NSColor {
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 48,
                pixelsHigh: 48,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        rep.size = NSSize(width: 24, height: 24)
        let context = try #require(
            NSGraphicsContext(bitmapImageRep: rep)
        )
        let look = try #require(NSAppearance(named: appearance))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        look.performAsCurrentDrawingAppearance {
            image.draw(in: NSRect(x: 0, y: 0, width: 24, height: 24))
        }
        NSGraphicsContext.restoreGraphicsState()
        let pixel = try #require(
            rep.colorAt(x: point.x * 2, y: point.y * 2)
        )
        return try #require(pixel.usingColorSpace(.sRGB))
    }

    private func hex(_ color: NSColor) throws -> String {
        let c = try #require(color.usingColorSpace(.sRGB))
        return String(
            format: "#%02X%02X%02X",
            Int((c.redComponent * 255).rounded()),
            Int((c.greenComponent * 255).rounded()),
            Int((c.blueComponent * 255).rounded())
        )
    }

    @Test("pocket.set_color stores a hex, empty resets, junk refused")
    func setColor() {
        let core = makeCore()
        #expect(PocketStyle().color == "")
        #expect(
            core.execute("pocket.set_color", args: [.string(amber)])
                .isSuccess
        )
        #expect(core.tiler.settings.pocketStyle.color == amber)
        #expect(
            !core.execute("pocket.set_color", args: [.string("red")])
                .isSuccess
        )
        #expect(core.tiler.settings.pocketStyle.color == amber)
        #expect(
            core.execute("pocket.set_color", args: [.string("")])
                .isSuccess
        )
        #expect(core.tiler.settings.pocketStyle.color == "")
    }

    @Test("a palette paints the pocket and reads it back")
    func paletteCarriesIt() {
        #expect(ColorPaletteKeys.all.contains("pocket.color"))
        var settings = TilingSettings()
        ColorPalette(name: "P", colors: ["pocket.color": amber])
            .apply(to: &settings)
        #expect(settings.pocketStyle.color == amber)
        #expect(
            ColorPaletteKeys.extract(from: settings)["pocket.color"]
                == amber
        )
    }

    @Test("out of the pocket the mark carries the pocket colour")
    func markCarriesTheColor() {
        let core = makeCore()
        core.tiler.settings.pocketStyle.color = amber
        core.tiler.settings.floatingStyle.color = "#112233"
        core.execute("pocket")
        core.execute("pocket")
        let glyphs = core.stickyMarkSpecs()
            .first { $0.window == WindowID(1) }?.glyphs
        #expect(glyphs == [.pocket(color: amber)])
        // The pocket fills itself; its plate stays untinted.
        #expect(glyphs?.first?.symbolHex == "")
    }

    /// A mark wearing `glyphs` on a window wide enough for two
    /// slots, in the manager's order: glyphs first, then the frame.
    private func plate(
        _ glyphs: [StickyMarkManager.Glyph]
    ) -> StickyMarkPlate {
        let overlay = StickyMarkOverlay(window: 1) { _, _ in false }
        defer { overlay.hide() }
        overlay.setGlass(false)
        overlay.setGlyphs(glyphs)
        overlay.update(
            frame: CGRect(x: -9_000, y: -9_000, width: 800, height: 500)
        )
        return overlay.plate
    }

    /// A floating glyph's colour goes on its symbol, outer slot or
    /// inner (#2831); the pocket's is drawn into its own image.
    @Test("a colour goes on its glyph's symbol")
    func colourOnSymbol() throws {
        let outer = plate([.floating(color: amber)])
        let tint = try #require(outer.symbol.contentTintColor)
        #expect(try hex(tint) == amber)
        let floating = plate([.sticky(), .floating(color: amber)])
        #expect(floating.slotCount == 2)
        let innerTint = try #require(floating.innerSymbol.contentTintColor)
        #expect(try hex(innerTint) == amber)
    }

    @Test("the window mark draws its pocket opaque in the colour")
    func markDrawsTheColor() throws {
        let image = StickyMarkOverlay.pocketImage(hex: amber)
        let pixel = try pocketPixel(image)
        #expect(pixel.alphaComponent == 1)
        #expect(try hex(pixel) == amber)
        // The outline takes the colour itself, never its
        // contrasting glyph ink (#2704). (4, 15) is on the
        // pocket's left edge.
        let edge = try pocketPixel(image, at: (4, 15))
        #expect(edge.alphaComponent == 1)
        #expect(try hex(edge) == amber)
    }

    /// The slices draw no outline in any ink (#2704; Automatic too,
    /// owner 2026-10-29): (4, 7) sits where the left slice's stroke
    /// drew, outside its green and above the pocket.
    @Test("every mark draws its kiwis bare")
    func kiwisAreBare() throws {
        for hex in [amber, ""] {
            let image = StickyMarkOverlay.pocketImage(hex: hex)
            #expect(try pocketPixel(image, at: (4, 7)).alphaComponent < 0.5)
            // Control: the slice itself draws, one point inside.
            #expect(try pocketPixel(image, at: (6, 7)).alphaComponent > 0.5)
        }
    }

    @Test("automatic fills the pocket opaque in the mark ink")
    func automaticFollowsTheInk() throws {
        let light = try pocketPixel(
            StickyMarkOverlay.pocketImage(hex: ""),
            appearance: .aqua
        )
        let dark = try pocketPixel(
            StickyMarkOverlay.pocketImage(hex: ""),
            appearance: .darkAqua
        )
        #expect(light.alphaComponent == 1)
        #expect(dark.alphaComponent == 1)
        // Near-black in light, near-white in dark: the label ink.
        #expect(light.redComponent < 0.2)
        #expect(dark.redComponent > 0.8)
    }

    @Test("the bar build hands the badges the pocket colour")
    func barTakesThePocketColor() {
        let core = makeCore()
        core.tiler.settings.floatingStyle.color = "#112233"
        core.tiler.settings.pocketStyle.color = amber
        #expect(core.stateMarkColors.pocket == amber)
        #expect(core.stateMarkColors.floating == "#112233")
    }

    @Test("the Space Bar's pocket badge fills its pocket in the colour")
    func badgeTakesTheColor() throws {
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 120, height: 28)
        )
        let style = SpaceBarLook()
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: [
                SpaceBarItemView.App(
                    name: "App",
                    icon: nil,
                    glyph: "A",
                    focused: true,
                    count: 1,
                    pocket: true
                )
            ],
            active: true,
            horizontal: true,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "",
                floating: "#112233",
                pocket: amber
            )
        )
        view.layout()
        let badge = try #require(view.pocketBadgeViews.first ?? nil)
        #expect(badge.symbolName == StateBadgeView.pocketName)
        // The pocket takes the colour; the disc stays the count
        // badge's own, as the window mark's plate stays untinted.
        #expect(try hex(badge.ink) == amber)
        let fill = try #require(
            badge.layer?.backgroundColor.flatMap(NSColor.init(cgColor:))
        )
        #expect(
            try hex(fill)
                == hex(NSColor(kiwiHex: style.groupBadgeColor))
        )
    }

    /// Each authored palette paints the pocket (#2704); its colour
    /// meets the unoutlined slices, so it clears the colour-vision
    /// floor against the kiwi green; the derived default keeps
    /// Automatic.
    @Test("every bundled palette's pocket separates from the kiwis")
    func bundledPocketsSeparateFromTheKiwis() throws {
        let kiwi = try hex(PocketMark.kiwi)
        let palettes = PaletteCatalog.authored()
        #expect(!palettes.isEmpty)
        for palette in palettes {
            let pocket = try #require(
                palette.colors["pocket.color"],
                Comment(rawValue: "\(palette.name) paints no pocket")
            )
            let separation = try #require(
                ColorVision.separation(kiwi, pocket)
            )
            #expect(
                separation >= ColorVision.separationFloor,
                Comment(
                    rawValue: "\(palette.name) \(pocket): \(separation)"
                )
            )
        }
    }

    @Test("kiwi green separates from the lightest and darkest ink")
    func kiwiSeparatesFromTheInk() throws {
        let kiwi = try hex(PocketMark.kiwi)
        var inks: Set<String> = []
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let look = try #require(NSAppearance(named: name))
            var resolved = NSColor.clear
            look.performAsCurrentDrawingAppearance {
                resolved = PocketMark.opaque(.labelColor)
            }
            let ink = try hex(resolved)
            inks.insert(ink)
            let separation = try #require(
                ColorVision.separation(kiwi, ink)
            )
            #expect(
                separation >= ColorVision.separationFloor,
                Comment(rawValue: "\(kiwi) vs \(ink): \(separation)")
            )
        }
        // Light and dark resolved two inks, or one was measured twice.
        #expect(inks.count == 2)
    }
}
