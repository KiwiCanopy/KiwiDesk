import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The grow, the `reveal_style` beside the slide (#761, owner
/// ruling 2026-10-21): the plate grows out of the mark as a clip of
/// the content's own layer while the items fade on it, and back; a
/// shelf with no plate cross-fades, and the mark keeps time with
/// each. Main-actor spend: a few overlays, one ordered panel each.
@Suite("Shelf reveal grow (#761)", .serialized)
@MainActor
struct ShelfRevealGrowTests {
    private static let mark = CGRect(x: 100, y: 0, width: 60, height: 8)
    private static let plate = CGRect(x: 20, y: 0, width: 360, height: 40)
    /// Clear of the menu bar, which AppKit keeps a panel below.
    private static let strip = CGRect(x: 100, y: 300, width: 1000, height: 40)

    private func morph(entering: Bool) -> ShelfGrow.Morph? {
        let motion = BarMotion.revealMotion(
            reduceMotion: false,
            entering: entering,
            path: .init(
                style: .grow,
                origin: Self.mark,
                plate: Self.plate,
                plateRadius: 10
            )
        )
        guard case .morph(let morph) = motion else { return nil }
        return morph
    }

    @Test("A grow reveal grows the plate out of the hovered mark")
    func growsOutOfTheMark() throws {
        let morph = try #require(morph(entering: true))
        let mark = BarMotion.hoverPlate(
            mark: Self.mark,
            hovered: true,
            reduceMotion: false
        )
        #expect(morph.mark == mark)
        #expect(morph.plate == Self.plate)
        #expect(morph.itemsStart > morph.plateStart)
        #expect(morph.itemsStart < morph.plateStart + morph.plateLength)
    }

    @Test("A grow retract fades the items before the plate shrinks")
    func retractFadesItemsFirst() throws {
        let morph = try #require(morph(entering: false))
        #expect(morph.plateStart >= morph.itemsStart + morph.itemsLength)
    }

    @Test("A grow with no plate cross-fades, and its mark with it")
    func platelessGrowFades() {
        #expect(
            BarMotion.revealMotion(
                reduceMotion: false,
                entering: true,
                path: .init(style: .grow, origin: Self.mark)
            ) == .fade(BarMotion.revealFade)
        )
        var shelf = KiwiShelf()
        shelf.revealStyle = .grow
        #expect(BarMotion.RevealKind(shelf) == .grow)
        shelf.backgroundStyle = .boxed
        #expect(BarMotion.RevealKind(shelf) == .fade)
        shelf.revealStyle = .slide
        #expect(BarMotion.RevealKind(shelf) == .slide)
    }

    @Test("The mark lands with a grow's retract")
    func markLandsWithTheGrow() throws {
        let retract = try #require(morph(entering: false))
        let back = BarMotion.markFade(
            showing: true,
            reveal: .grow,
            reduceMotion: false
        )
        #expect(back.delay > 0)
        #expect(abs(back.delay + back.length - retract.length) < 1e-9)
    }

    /// A shown shelf whose reveal grows, its landings swallowed.
    private func overlay() -> ShelfOverlay {
        let overlay = ShelfOverlay()
        overlay.afterReveal = { _, _ in }
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        shelf.revealStyle = .grow
        overlay.show(
            strip: Self.strip,
            edge: .top,
            shelf: shelf,
            sheen: 0,
            sections: [
                .init(
                    view: NSView(),
                    slot: Self.strip,
                    plate: Self.plate,
                    content: Self.plate
                )
            ]
        )
        overlay.revealOrigin = Self.mark
        return overlay
    }

    @Test("A grow clips the content's own layer and fades the items")
    func growPlaysBothChannels() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay()
        defer { overlay.hide() }
        overlay.revealIn()
        #expect(overlay.content.layer?.mask == nil)
        let plate = try #require(
            overlay.content.layer?.animation(forKey: BarMotion.revealKey)
        )
        let items = try #require(
            overlay.stripView.layer?.animation(forKey: BarMotion.revealKey)
        )
        #expect(plate is CAAnimationGroup)
        #expect(items.beginTime > plate.beginTime)
        // The clip is placed in the panel's coordinates, so the room
        // is the whole strip while it plays.
        let panel = try #require(overlay.panel)
        let whole = GeometryUtils.flip(
            Self.strip,
            primaryHeight: GeometryUtils.primaryHeight
        )
        #expect(panel.frame == whole)
    }
}
