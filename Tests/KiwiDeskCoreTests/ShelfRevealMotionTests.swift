import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// How a hiding shelf's reveal and its mark's hover MOVE (#761):
/// the plate morphs out of the mark as a clip of the content's own
/// layer while the items fade on it, starting only after the pass
/// that orders the panel in, and the hovered plate grows its frame
/// rather than cross-fading a redraw. Whether it reads well is the
/// device's; this holds the decisions and the start order, never
/// the tuned values. Main-actor spend: a handful of unwindowed
/// views.
@Suite("Shelf reveal motion (#761)")
@MainActor
struct ShelfRevealMotionTests {
    private static let mark = CGRect(x: 100, y: 0, width: 60, height: 8)
    private static let plate = CGRect(x: 20, y: 0, width: 360, height: 40)

    @Test("The hovered plate grows on every side, never under Reduce Motion")
    func hoverPlateGrows() {
        let grown = BarMotion.hoverPlate(
            mark: Self.mark,
            hovered: true,
            reduceMotion: false
        )
        let growth = ShelfIndicatorSpec.hoverGrowth
        #expect(grown == Self.mark.insetBy(dx: -growth, dy: -growth))
        #expect(
            BarMotion.hoverPlate(
                mark: Self.mark,
                hovered: true,
                reduceMotion: true
            ) == Self.mark
        )
        #expect(
            BarMotion.hoverPlate(
                mark: Self.mark,
                hovered: false,
                reduceMotion: false
            ) == Self.mark
        )
    }

    private func morph(entering: Bool) -> BarMotion.Morph? {
        let motion = BarMotion.revealMotion(
            reduceMotion: false,
            entering: entering,
            origin: Self.mark,
            plate: Self.plate,
            plateRadius: 10
        )
        guard case .morph(let morph) = motion else { return nil }
        return morph
    }

    @Test("A reveal grows the plate out of the hovered mark, items after")
    func revealMorphsOutOfTheMark() throws {
        let morph = try #require(morph(entering: true))
        let mark = BarMotion.hoverPlate(
            mark: Self.mark,
            hovered: true,
            reduceMotion: false
        )
        #expect(morph.mark == mark)
        #expect(morph.plate == Self.plate)
        // The items fade up once the plate moves, while it still
        // grows: one overlapping sequence.
        #expect(morph.itemsStart > morph.plateStart)
        #expect(morph.itemsStart < morph.plateStart + morph.plateLength)
    }

    @Test("A retract fades the items before the plate shrinks")
    func retractFadesItemsFirst() throws {
        let morph = try #require(morph(entering: false))
        #expect(morph.plateStart >= morph.itemsStart + morph.itemsLength)
    }

    @Test("A Boxed shelf and Reduce Motion cross-fade in place")
    func boxedAndReducedFade() {
        for entering in [true, false] {
            let boxed = BarMotion.revealMotion(
                reduceMotion: false,
                entering: entering,
                origin: Self.mark,
                plate: nil,
                plateRadius: 0
            )
            let reduced = BarMotion.revealMotion(
                reduceMotion: true,
                entering: entering,
                origin: Self.mark,
                plate: Self.plate,
                plateRadius: 10
            )
            #expect(boxed == .fade(BarMotion.revealFade))
            #expect(reduced == .fade(BarMotion.revealFade))
        }
    }

    @Test("The mark lands with a morph's retract, and cross-fades else")
    func markFadeFollowsTheShelf() throws {
        let retract = try #require(morph(entering: false))
        let back = BarMotion.markFade(
            showing: true,
            morphs: true,
            reduceMotion: false
        )
        #expect(back.delay > 0)
        #expect(abs(back.delay + back.length - retract.length) < 1e-9)
        let out = BarMotion.markFade(
            showing: false,
            morphs: true,
            reduceMotion: false
        )
        #expect(out.delay == 0)
        for (morphs, reduced) in [(false, false), (true, true)] {
            for showing in [true, false] {
                let fade = BarMotion.markFade(
                    showing: showing,
                    morphs: morphs,
                    reduceMotion: reduced
                )
                #expect(fade.delay == 0)
                #expect(fade.length == BarMotion.revealFade)
            }
        }
    }

    private func spec(hovered: Bool, shown: Bool = false)
        -> ShelfIndicatorSpec
    {
        ShelfIndicatorSpec(
            mark: .dots([.init(current: true, occupied: true)]),
            frame: Self.mark,
            horizontal: true,
            fill: "#000000",
            currentInk: "#FFFFFF",
            ink: "#AAAAAA",
            emptyInk: "#555555",
            highlight: "#FF0000",
            shown: shown,
            hovered: hovered
        )
    }

    /// The indicator view sized as `ShelfIndicator.show` sizes it.
    private func view() -> ShelfIndicatorView {
        let room = ShelfIndicatorSpec.hoverGrowth
        let view = ShelfIndicatorView()
        view.frame = CGRect(
            origin: .zero,
            size: Self.mark.insetBy(dx: -room, dy: -room).size
        )
        return view
    }

    @Test("A hover grows the plate's frame and leaves the dots alone")
    func hoverGrowsThePlate() {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let view = view()
        view.render(spec(hovered: false), animated: false)
        let room = ShelfIndicatorSpec.hoverGrowth
        let resting = view.bounds.insetBy(dx: room, dy: room)
        #expect(view.plate.frame == resting)
        #expect(view.dots.frame == resting)
        #expect(view.rim.alphaValue == 0)
        view.render(spec(hovered: true), animated: false)
        #expect(view.plate.frame == view.bounds)
        #expect(view.rim.frame == view.bounds)
        #expect(view.dots.frame == resting)
        #expect(view.rim.alphaValue == 1)
    }

    @Test("Under Reduce Motion a hover takes the rim alone")
    func reducedHoverIsTheRim() {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let view = view()
        view.render(spec(hovered: true), animated: true)
        let room = ShelfIndicatorSpec.hoverGrowth
        #expect(view.plate.frame == view.bounds.insetBy(dx: room, dy: room))
        #expect(view.rim.frame == view.plate.frame)
        #expect(view.rim.alphaValue == 1)
    }
}
