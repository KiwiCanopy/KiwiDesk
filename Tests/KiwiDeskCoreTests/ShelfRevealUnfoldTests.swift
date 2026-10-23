import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The unfold, the third `reveal_style` (owner ruling 2026-10-21):
/// on a plate the clip stretches out of the mark along the edge and
/// then deepens, the items rising on it, and collapses back through
/// the stretch; the mark keeps time with each, and Reduce Motion
/// keeps it. Its decisions and the channels it starts, never its
/// tuned values. Main-actor spend: a few overlays, one ordered panel
/// each.
@Suite("Shelf reveal unfold", .serialized)
@MainActor
struct ShelfRevealUnfoldTests {
    private static let mark = CGRect(x: 100, y: 0, width: 60, height: 8)
    private static let plate = CGRect(x: 20, y: 0, width: 360, height: 40)
    /// Clear of the menu bar, which AppKit keeps a panel below.
    private static let strip = CGRect(x: 100, y: 300, width: 1000, height: 40)

    private var hovered: CGRect {
        BarMotion.hoverPlate(mark: Self.mark, edge: .top, hovered: true)
    }

    private func stretch(entering: Bool) -> ShelfUnfold.Stretch? {
        let motion = BarMotion.revealMotion(
            entering: entering,
            path: .init(
                kind: .unfold,
                origin: Self.mark,
                plate: Self.plate,
                plateRadius: 10
            )
        )
        guard case .unfold(let stretch) = motion else { return nil }
        return stretch
    }

    @Test("The stretch runs the plate's length at the mark's depth")
    func stretchesAlongTheEdge() throws {
        let stretch = try #require(stretch(entering: true))
        #expect(stretch.mark == hovered)
        #expect(stretch.along.minX == Self.plate.minX)
        #expect(stretch.along.width == Self.plate.width)
        #expect(stretch.along.minY == hovered.minY)
        #expect(stretch.along.height == hovered.height)
        let side = ShelfUnfold.along(
            mark: hovered,
            plate: Self.plate,
            horizontal: false
        )
        #expect(side.height == Self.plate.height)
        #expect(side.width == hovered.width)
    }

    @Test("The mark lands with an unfold's retract")
    func markLandsWithTheRetract() throws {
        let retract = try #require(stretch(entering: false))
        let back = BarMotion.markFade(showing: true, reveal: .unfold)
        #expect(back.delay > 0)
        #expect(abs(back.delay + back.length - retract.length) < 1e-9)
        let gather = BarMotion.markFade(showing: true, reveal: .spread)
        #expect(
            abs(gather.delay + gather.length - ShelfUnfold.gatherLength)
                < 1e-9
        )
    }

    @Test("A spring's overshoot grows the room, a critical one none")
    func roomHoldsTheSwing() {
        #expect(ShelfUnfold.overshoot(bounce: 0) == 0)
        #expect(ShelfUnfold.overshoot(bounce: 0.15) > 0)
        #expect(
            ShelfUnfold.overshoot(bounce: 0.3)
                > ShelfUnfold.overshoot(bounce: 0.15)
        )
        let rest = CGRect(x: 100, y: 0, width: 200, height: 40)
        let room = ShelfUnfold.room(
            rest,
            travel: 1000,
            bounce: 0.3,
            horizontal: true
        )
        #expect(room.minX < rest.minX && room.maxX > rest.maxX)
        #expect(room.minY == rest.minY && room.height == rest.height)
    }

    /// A shown plate shelf whose reveal is an unfold.
    private func overlay() -> ShelfOverlay {
        let overlay = ShelfOverlay()
        overlay.afterReveal = { _, _ in }
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        shelf.revealStyle = .unfold
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

    private func spring(
        _ clip: CAAnimationGroup,
        _ path: String
    ) -> CASpringAnimation? {
        clip.animations?.first {
            ($0 as? CASpringAnimation)?.keyPath == path
        } as? CASpringAnimation
    }

    /// Under Reduce Motion, which the owner ruled keeps the reveal.
    @Test("An unfold stretches first and deepens second")
    func revealPlaysTwoStages() throws {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay()
        defer { overlay.hide() }
        overlay.revealIn()
        let layer = try #require(overlay.content.layer)
        let clip = try #require(
            layer.animation(forKey: BarMotion.revealKey) as? CAAnimationGroup
        )
        let along = try #require(spring(clip, "bounds.size.width"))
        let deep = try #require(spring(clip, "bounds.size.height"))
        #expect(along.fromValue as? CGFloat == hovered.width)
        #expect(along.toValue as? CGFloat == Self.plate.width)
        #expect(deep.fromValue as? CGFloat == hovered.height)
        #expect(deep.toValue as? CGFloat == Self.plate.height)
        #expect(deep.beginTime > along.beginTime)
        let items = try #require(
            overlay.stripView.layer?.animation(forKey: BarMotion.revealKey)
        )
        #expect(items.beginTime > clip.beginTime)
        // The clip holds the room still until it lands.
        #expect(overlay.growing)
    }

    @Test("An unfold retract collapses back through the stretch")
    func retractCollapsesThroughTheStretch() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay()
        defer { overlay.hide() }
        overlay.panel?.orderFrontRegardless()
        #expect(overlay.retractOut())
        let clip = try #require(
            overlay.content.layer?.animation(forKey: BarMotion.revealKey)
                as? CAAnimationGroup
        )
        let bounds = try #require(
            clip.animations?.first {
                ($0 as? CAKeyframeAnimation)?.keyPath == "bounds"
            } as? CAKeyframeAnimation
        )
        let values = (bounds.values ?? []).compactMap {
            ($0 as? NSValue)?.rectValue
        }
        let stretch = try #require(stretch(entering: false))
        #expect(values.dropFirst().first == stretch.along)
        #expect(values.last == hovered)
        let items = try #require(
            overlay.stripView.layer?.animation(forKey: BarMotion.revealKey)
        )
        #expect(clip.beginTime > items.beginTime)
    }
}
