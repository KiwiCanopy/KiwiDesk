import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The #1413 composite's pixels, split from
/// `StatusItemSpaceMarkTests` for the file ceiling: a template
/// unless an emoji is in it, a symbol beside an emoji following
/// the appearance rather than drawing its own black, and the
/// #1013 mark leaving an emoji its colours. `@MainActor` for the
/// image draws; nothing here touches a button or the locale.
@Suite("Status item Space mark drawing (#1413)")
@MainActor
struct StatusItemSpaceMarkDrawingTests {
    private func display(_ id: UInt32, x: CGFloat) -> Display {
        Display(
            id: DisplayID(id),
            name: "\(id)",
            frame: CGRect(x: x, y: 0, width: 1000, height: 600)
        )
    }

    private func screen(
        _ id: UInt32,
        x: CGFloat,
        space: String,
        glyph: StatusSpaceMark.Glyph? = nil
    ) -> StatusSpaceMark.Screen {
        StatusSpaceMark.Screen(
            display: display(id, x: x),
            space: SpaceID(space),
            glyph: glyph ?? .text(space, tinted: true)
        )
    }

    private func layer(
        _ name: String,
        glyph: StatusSpaceMark.Glyph,
        hasIcon: Bool = true
    ) -> StatusSpaceMark.Layer {
        .init(name: name, glyph: glyph, hasIcon: hasIcon)
    }

    /// The image rendered under `appearance`, so a colour the
    /// handler resolves per appearance can be read both ways.
    private func bitmap(
        _ image: NSImage,
        under appearance: NSAppearance.Name
    ) -> NSBitmapImageRep? {
        var rep: NSBitmapImageRep?
        NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
            guard
                let cg = image.cgImage(
                    forProposedRect: nil,
                    context: nil,
                    hints: nil
                )
            else { return }
            rep = NSBitmapImageRep(cgImage: cg)
        }
        return rep
    }

    /// Distinct saturated hues among the opaque pixels, in
    /// twelfths: a template glyph has none, an emoji several, the
    /// #1013 dot one (orange).
    private func hues(
        _ rep: NSBitmapImageRep,
        in range: Range<Int>? = nil
    ) -> Set<Int> {
        var found: Set<Int> = []
        let xs = range ?? 0..<rep.pixelsWide
        for x in xs {
            for y in 0..<rep.pixelsHigh {
                guard
                    let color = rep.colorAt(x: x, y: y)?
                        .usingColorSpace(.sRGB),
                    color.alphaComponent > 0.5,
                    color.saturationComponent > 0.3
                else { continue }
                found.insert(Int(color.hueComponent * 12) % 12)
            }
        }
        return found
    }

    /// Mean brightness of the opaque pixels in a column range.
    private func brightness(
        _ rep: NSBitmapImageRep,
        in range: Range<Int>
    ) -> CGFloat {
        var total: CGFloat = 0
        var count: CGFloat = 0
        for x in range {
            for y in 0..<rep.pixelsHigh {
                guard
                    let color = rep.colorAt(x: x, y: y)?
                        .usingColorSpace(.sRGB),
                    color.alphaComponent > 0.5
                else { continue }
                total += color.brightnessComponent
                count += 1
            }
        }
        return count > 0 ? total / count : -1
    }

    @Test("an emoji keeps its colour: the image is no template")
    func emojiIsNoTemplate() throws {
        let image = StatusItemController.spaceMarkImage(
            StatusSpaceMark(
                layer: nil,
                screens: [
                    screen(
                        1,
                        x: 0,
                        space: "web",
                        glyph: .text("🌐", tinted: false)
                    )
                ]
            )
        )
        #expect(image.isTemplate == false)
        #expect(!hues(try #require(bitmap(image, under: .aqua))).isEmpty)
    }

    /// Beside an emoji the composite is no template, so a symbol
    /// run must take the label colour itself: light on a dark
    /// bar, dark on a light one — never its own black.
    @Test("a symbol beside an emoji follows the appearance")
    func symbolBesideEmojiFollowsAppearance() throws {
        let image = StatusItemController.spaceMarkImage(
            StatusSpaceMark(
                layer: layer("resize", glyph: .symbol("square.fill")),
                screens: [
                    screen(
                        1,
                        x: 0,
                        space: "web",
                        glyph: .text("🌐", tinted: false)
                    )
                ]
            )
        )
        // The symbol is the first run; its columns are the ones
        // before the divider, which sits past its width.
        let symbolColumns = 0..<10
        let dark = try #require(bitmap(image, under: .darkAqua))
        let light = try #require(bitmap(image, under: .aqua))
        #expect(brightness(dark, in: symbolColumns) > 0.6)
        #expect(brightness(light, in: symbolColumns) < 0.4)
    }

    /// The #1013 mark keeps an emoji's colours: its tint fill
    /// is the template's alone.
    @Test("the update mark leaves an emoji its colours")
    func updateMarkKeepsEmojiColours() throws {
        let emoji = StatusItemController.spaceMarkImage(
            StatusSpaceMark(
                layer: nil,
                screens: [
                    screen(
                        1,
                        x: 0,
                        space: "web",
                        glyph: .text("🌐", tinted: false)
                    )
                ]
            )
        )
        let badged = StatusItemController.badged(emoji)
        #expect(hues(try #require(bitmap(badged, under: .aqua))).count > 1)
        // The control: a template composite under the mark shows
        // the dot's hue and nothing else.
        let template = StatusItemController.spaceMarkImage(
            StatusSpaceMark(
                layer: nil,
                screens: [screen(1, x: 0, space: "main")]
            )
        )
        let marked = StatusItemController.badged(template)
        #expect(hues(try #require(bitmap(marked, under: .aqua))).count == 1)
    }

    /// A one-glyph mark and a two-glyph mark differ by a divider
    /// and the second glyph: the composite grows with its runs.
    @Test("a second glyph widens the image")
    func widthGrowsWithRuns() {
        let one = StatusItemController.spaceMarkImage(
            StatusSpaceMark(
                layer: nil,
                screens: [screen(1, x: 0, space: "main")]
            )
        )
        let two = StatusItemController.spaceMarkImage(
            StatusSpaceMark(
                layer: layer("resize", glyph: .text("RE", tinted: true)),
                screens: [screen(1, x: 0, space: "main")]
            )
        )
        #expect(two.size.width > one.size.width + 10)
        #expect(one.size.height == two.size.height)
    }
}
