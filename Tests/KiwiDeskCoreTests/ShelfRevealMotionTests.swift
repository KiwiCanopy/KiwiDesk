import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// How a hiding shelf's reveal and its mark's hover MOVE (#761,
/// #2497): the whole shelf slides in from past its screen side and
/// the mark fades as it starts, and the hovered plate grows its
/// frame rather than cross-fading a redraw. Whether it reads well is the
/// device's; this holds the decisions and the start order, never
/// the tuned values. Main-actor spend: a handful of unwindowed
/// views.
@Suite("Shelf reveal motion (#761)")
@MainActor
struct ShelfRevealMotionTests {
    private static let mark = CGRect(x: 100, y: 0, width: 60, height: 8)

    @Test("The hovered plate grows on every side")
    func hoverPlateGrows() {
        let grown = BarMotion.hoverPlate(mark: Self.mark, hovered: true)
        let growth = ShelfIndicatorSpec.hoverGrowth
        #expect(grown == Self.mark.insetBy(dx: -growth, dy: -growth))
        #expect(
            BarMotion.hoverPlate(mark: Self.mark, hovered: false)
                == Self.mark
        )
    }

    /// A slide along `offset`.
    private func slide(_ offset: CGVector) -> BarMotion.RevealPath {
        BarMotion.RevealPath(kind: .slide, offset: offset)
    }

    @Test("A reveal slides from past the screen side, by edge")
    func revealSlidesFromTheEdge() {
        let depth: CGFloat = 40
        let gap: CGFloat = 6
        let offsets: [(AppBarEdge, CGVector)] = [
            (.top, CGVector(dx: 0, dy: -46)),
            (.bottom, CGVector(dx: 0, dy: 46)),
            (.left, CGVector(dx: -46, dy: 0)),
            (.right, CGVector(dx: 46, dy: 0)),
        ]
        for (edge, offset) in offsets {
            let found = BarMotion.revealOffset(
                edge: edge,
                depth: depth,
                gap: gap
            )
            #expect(found == offset)
            #expect(
                BarMotion.revealMotion(
                    reduceMotion: false,
                    entering: true,
                    path: slide(found)
                ) == .slide(offset: offset, length: BarMotion.revealSlide)
            )
        }
    }

    @Test("Reduce Motion, or nothing to travel, cross-fades in place")
    func reducedFades() {
        let offset = CGVector(dx: 0, dy: -46)
        for path in [slide(offset), .init(kind: .grow, plate: Self.mark)] {
            #expect(
                BarMotion.revealMotion(
                    reduceMotion: true,
                    entering: true,
                    path: path
                ) == .fade(BarMotion.revealFade)
            )
        }
        #expect(
            BarMotion.revealMotion(
                reduceMotion: false,
                entering: true,
                path: slide(.zero)
            ) == .fade(BarMotion.revealFade)
        )
    }

    @Test("The mark fades as the slide starts and lands with the retract")
    func markFadeFollowsTheSlide() {
        let back = BarMotion.markFade(
            showing: true,
            reveal: .slide,
            reduceMotion: false
        )
        #expect(back.delay > 0)
        #expect(abs(back.delay + back.length - BarMotion.revealSlide) < 1e-9)
        let out = BarMotion.markFade(
            showing: false,
            reveal: .slide,
            reduceMotion: false
        )
        #expect(out.delay == 0)
        for kind in [BarMotion.RevealKind.slide, .grow, .fade] {
            for showing in [true, false] {
                let fade = BarMotion.markFade(
                    showing: showing,
                    reveal: kind,
                    reduceMotion: true
                )
                #expect(fade.delay == 0)
                #expect(fade.length == BarMotion.revealFade)
            }
        }
    }

    private func spec(
        hovered: Bool,
        shown: Bool = false,
        label: ShelfIndicatorSpec.Label? = nil
    ) -> ShelfIndicatorSpec {
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
            hovered: hovered,
            reveal: .slide,
            label: label
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
        #expect(view.dots.mark == resting)
        #expect(view.rim.alphaValue == 0)
        view.render(spec(hovered: true), animated: false)
        #expect(view.plate.frame == view.bounds)
        #expect(view.rim.frame == view.bounds)
        #expect(view.dots.mark == resting)
        #expect(view.rim.alphaValue == 1)
    }

    @Test("The hover growth travels only without Reduce Motion")
    func hoverGrowDurationGates() {
        #expect(BarMotion.hoverGrowDuration(reduceMotion: true) == 0)
        #expect(BarMotion.hoverGrowDuration(reduceMotion: false) > 0)
    }

    /// The size is content, not motion: an unlabelled mark (a lone
    /// App Bar's line) grows like a labelled one (owner, device,
    /// 2026-10-21).
    @Test("Under Reduce Motion a hover grows the plate at once")
    func reducedHoverGrowsThePlate() {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let view = view()
        view.render(spec(hovered: true), animated: true)
        #expect(view.plate.frame == view.bounds)
        #expect(view.rim.frame == view.plate.frame)
        #expect(view.rim.alphaValue == 1)
        #expect(view.plate.layer?.animationKeys() == nil)
    }

    /// A label narrower than the current dot widens nothing, yet
    /// still needs the grown plate's depth: under Reduce Motion the
    /// plate takes its hovered frame at once rather than staying
    /// thin under the pill (owner, device, 2026-10-21).
    @Test("Under Reduce Motion a labelled mark's plate grows at once")
    func reducedLabelGrowsThePlate() {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let label = ShelfIndicatorSpec.label(
            .text("1", tinted: true),
            font: NSFont.systemFont(ofSize: 8)
        )
        let view = view()
        view.render(spec(hovered: true, label: label), animated: true)
        #expect(spec(hovered: true, label: label).labelExtra == 0)
        #expect(view.plate.frame == view.bounds)
    }
}
