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
            entering: entering,
            path: .init(
                kind: .grow,
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
            edge: .top,
            hovered: true
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

    /// Boxed draws no plate, so an unfold spreads the boxes (owner
    /// ruling, 2026-10-21) and a grow plays that spread (#2556); a
    /// grow path with no plate — a shelf not yet shown — cross-fades.
    @Test("Boxed spreads its unfold, and its grow plays as one")
    func boxedKinds() {
        #expect(
            BarMotion.revealMotion(
                entering: true,
                path: .init(kind: .grow, origin: Self.mark)
            ) == .fade(BarMotion.revealFade)
        )
        var shelf = KiwiShelf()
        shelf.revealStyle = .grow
        #expect(BarMotion.RevealKind(shelf) == .grow)
        shelf.revealStyle = .unfold
        #expect(BarMotion.RevealKind(shelf) == .unfold)
        shelf.backgroundStyle = .boxed
        #expect(BarMotion.RevealKind(shelf) == .spread)
        shelf.revealStyle = .grow
        #expect(BarMotion.RevealKind(shelf) == .spread)
        shelf.revealStyle = .slide
        #expect(BarMotion.RevealKind(shelf) == .slide)
        shelf.revealStyle = .fade
        #expect(BarMotion.RevealKind(shelf) == .fade)
    }

    @Test("The mark lands with a grow's retract")
    func markLandsWithTheGrow() throws {
        let retract = try #require(morph(entering: false))
        let back = BarMotion.markFade(showing: true, reveal: .grow)
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
        overlay.revealMark = .init(frame: Self.mark)
        return overlay
    }

    @Test("A grow clips the content's own layer from the mark to the plate")
    func growPlaysBothChannels() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay()
        defer { overlay.hide() }
        overlay.revealIn()
        let layer = try #require(overlay.content.layer)
        let clip = try #require(
            layer.animation(forKey: BarMotion.revealKey) as? CAAnimationGroup
        )
        let bounds = try #require(
            clip.animations?.first {
                ($0 as? CABasicAnimation)?.keyPath == "bounds"
            }
                as? CABasicAnimation
        )
        let hovered = BarMotion.hoverPlate(
            mark: Self.mark,
            edge: .top,
            hovered: true
        )
        // Out of the hovered mark onto the plate, never the reverse.
        #expect((bounds.fromValue as? NSValue)?.rectValue == hovered)
        #expect((bounds.toValue as? NSValue)?.rectValue == Self.plate)
        let items = try #require(
            overlay.stripView.layer?.animation(forKey: BarMotion.revealKey)
                as? CABasicAnimation
        )
        #expect(items.keyPath == "opacity")
        #expect(items.beginTime > clip.beginTime)
        // The room holds the plate and the mark, never the strip.
        let panel = try #require(overlay.panel)
        let room = Self.plate.union(hovered).offsetBy(
            dx: Self.strip.minX,
            dy: Self.strip.minY
        ).integral
        #expect(
            panel.frame
                == GeometryUtils.flip(
                    room,
                    primaryHeight: GeometryUtils.primaryHeight
                )
        )
    }

    /// A grow's clip is placed in the panel's coordinates, so a
    /// glide inside it moves no room until the grow lands.
    @Test("A grow's room holds still under a glide")
    func growRoomHoldsStill() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        pinShelfGlide()
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        var landings: [() -> Void] = []
        overlay.afterReveal = { _, body in landings.append(body) }
        overlay.afterGlide = { landings.append($0) }
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        shelf.revealStyle = .grow
        let view = NSView()
        let show = { (plate: CGRect) in
            overlay.show(
                strip: Self.strip,
                edge: .top,
                shelf: shelf,
                sheen: 0,
                sections: [
                    .init(
                        view: view,
                        slot: Self.strip,
                        plate: plate,
                        content: plate
                    )
                ]
            )
        }
        show(Self.plate)
        overlay.revealMark = .init(frame: Self.mark)
        overlay.revealIn()
        let panel = try #require(overlay.panel)
        let held = panel.frame
        show(Self.plate.offsetBy(dx: 400, dy: 0))
        #expect(panel.frame == held)
        for landing in landings { landing() }
        #expect(panel.frame != held)
    }

    @Test("A grow onto an edge with no mark starts at its screen side")
    func marklessGrowStartsAtTheScreenSide() {
        let rest = CGRect(x: 0, y: 200, width: 40, height: 300)
        let cases: [(AppBarEdge, CGPoint)] = [
            (.top, CGPoint(x: 20, y: 200)),
            (.bottom, CGPoint(x: 20, y: 500)),
            (.left, CGPoint(x: 0, y: 350)),
            (.right, CGPoint(x: 40, y: 350)),
        ]
        for (edge, point) in cases {
            #expect(
                ShelfOverlay.screenSide(of: rest, edge: edge)
                    == CGRect(origin: point, size: .zero),
                "\(edge)"
            )
        }
    }
}
