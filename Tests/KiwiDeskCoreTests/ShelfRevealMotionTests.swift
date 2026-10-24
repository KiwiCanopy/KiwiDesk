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

    /// The screen side of `rect` on `edge`, y down.
    private func screenSide(_ rect: CGRect, _ edge: AppBarEdge) -> CGFloat {
        switch edge {
        case .top: rect.minY
        case .bottom: rect.maxY
        case .left: rect.minX
        case .right: rect.maxX
        }
    }

    /// A plain `NSPanel` is clamped below the menu bar (#436), so a
    /// plate reaching past the screen side moved the mark off the
    /// edge and the grow reveal jumped as it landed.
    @Test("The hovered plate grows away from the screen side alone")
    func hoverPlateKeepsTheScreenSide() {
        let mark = CGRect(x: 100, y: 100, width: 60, height: 8)
        let growth = ShelfHandleSpec.hoverGrowth
        for edge in AppBarEdge.allCases {
            let rest =
                edge.isHorizontal
                ? mark : CGRect(x: 100, y: 100, width: 8, height: 60)
            let grown = BarMotion.hoverPlate(
                mark: rest,
                edge: edge,
                hovered: true
            )
            #expect(
                screenSide(grown, edge) == screenSide(rest, edge),
                "\(edge)"
            )
            #expect(grown.contains(rest), "\(edge)")
            let along = edge.isHorizontal ? \CGRect.width : \.height
            let across = edge.isHorizontal ? \CGRect.height : \.width
            #expect(grown[keyPath: along] == rest[keyPath: along] + 2 * growth)
            #expect(
                grown[keyPath: across] == rest[keyPath: across] + 2 * growth
            )
            #expect(
                BarMotion.hoverPlate(mark: rest, edge: edge, hovered: false)
                    == rest
            )
        }
    }

    @Test("The mark's panel and a grow's mark keep the screen side")
    func roomKeepsTheScreenSide() throws {
        let label = ShelfHandleSpec.label(
            .text("MA", tinted: true),
            font: NSFont.systemFont(ofSize: 8)
        )
        for edge in AppBarEdge.allCases {
            let frame =
                edge.isHorizontal
                ? CGRect(x: 100, y: 100, width: 60, height: 8)
                : CGRect(x: 100, y: 100, width: 8, height: 60)
            let spec = spec(hovered: true, label: label, edge: edge, at: frame)
            let room = ShelfHandle.room(of: spec)
            #expect(screenSide(room, edge) == screenSide(frame, edge))
            #expect(room.contains(frame), "\(edge)")
            let motion = BarMotion.revealMotion(
                entering: true,
                path: .init(
                    kind: .grow,
                    origin: frame,
                    plate: frame.insetBy(dx: -200, dy: -200),
                    edge: edge
                )
            )
            guard case .morph(let morph) = motion else {
                Issue.record("\(edge): no grow")
                continue
            }
            #expect(screenSide(morph.mark, edge) == screenSide(frame, edge))
        }
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
                BarMotion.revealMotion(entering: true, path: slide(found))
                    == .slide(offset: offset, length: BarMotion.revealSlide)
            )
        }
    }

    @Test("Nothing to travel cross-fades in place")
    func nothingToTravelFades() {
        #expect(
            BarMotion.revealMotion(entering: true, path: slide(.zero))
                == .fade(BarMotion.revealFade)
        )
    }

    @Test("The mark fades as the slide starts and lands with the retract")
    func markFadeFollowsTheSlide() {
        let back = BarMotion.markFade(showing: true, reveal: .slide)
        #expect(back.delay > 0)
        #expect(abs(back.delay + back.length - BarMotion.revealSlide) < 1e-9)
        let out = BarMotion.markFade(showing: false, reveal: .slide)
        #expect(out.delay == 0)
    }

    /// The owner's ruling (2026-10-21): the mark keeps time with
    /// the motion under Reduce Motion too, rather than cross-fading.
    @Test("Under Reduce Motion the mark still keeps the motion's time")
    func reducedMarkKeepsTime() throws {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let body = NSView()
        BarMotion.fadeMark(body, showing: true, reveal: .slide)
        let fade = try #require(
            body.layer?.animation(forKey: BarMotion.revealKey)
        )
        let back = BarMotion.markFade(showing: true, reveal: .slide)
        let scale = BarMotion.revealScale(
            BarMotion.naturalLength(.slide, entering: false),
            entering: false,
            BarMotion.revealLength
        )
        #expect(abs(fade.duration - back.length * scale) < 1e-9)
        #expect(back.delay > 0)
    }

    private func spec(
        hovered: Bool,
        shown: Bool = false,
        label: ShelfHandleSpec.Label? = nil,
        edge: AppBarEdge = .top,
        at frame: CGRect = ShelfRevealMotionTests.mark
    ) -> ShelfHandleSpec {
        ShelfHandleSpec(
            mark: .dots([.init(current: true, occupied: true)]),
            frame: frame,
            edge: edge,
            fill: GlassFill(hex: "#000000"),
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

    /// The handle view sized as `ShelfHandle.show` sizes it.
    private func view() -> ShelfHandleView {
        let view = ShelfHandleView()
        view.frame = CGRect(
            origin: .zero,
            size: ShelfHandle.room(of: spec(hovered: false)).size
        )
        return view
    }

    /// The dots' mark in the handle view's own coordinates.
    private func drawnMark(_ view: ShelfHandleView) -> CGRect {
        view.dots.mark.offsetBy(
            dx: view.dots.frame.minX,
            dy: view.dots.frame.minY
        )
    }

    @Test("A hover grows the plate's frame and the dots follow its middle")
    func hoverGrowsThePlate() {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let view = view()
        view.render(spec(hovered: false), animated: false)
        let resting = ShelfHandle.mark(
            of: spec(hovered: false),
            in: view.bounds
        )
        #expect(view.plate.frame == resting)
        #expect(drawnMark(view) == resting)
        #expect(view.rim.alphaValue == 0)
        view.render(spec(hovered: true), animated: false)
        #expect(view.plate.frame == view.bounds)
        #expect(view.rim.frame == view.bounds)
        #expect(drawnMark(view).midY == view.plate.frame.midY)
        #expect(view.rim.alphaValue == 1)
    }

    /// The size is content, and the growth is motion the owner
    /// keeps under Reduce Motion (2026-10-21): an unlabelled mark (a
    /// lone App Bar's line) grows like a labelled one.
    @Test("Under Reduce Motion a hover still grows the plate")
    func reducedHoverGrowsThePlate() {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let view = view()
        view.render(spec(hovered: false), animated: false)
        view.render(spec(hovered: true), animated: true)
        #expect(view.plate.frame == view.bounds)
        #expect(view.rim.frame == view.plate.frame)
        #expect(view.rim.alphaValue == 1)
        #expect(view.plate.layer?.animationKeys()?.isEmpty == false)
    }

    /// A label narrower than the current dot widens nothing, yet
    /// still needs the grown plate's depth: under Reduce Motion the
    /// plate takes its hovered frame rather than staying thin under
    /// the pill (owner, device, 2026-10-21).
    @Test("Under Reduce Motion a labelled mark's plate grows")
    func reducedLabelGrowsThePlate() {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let label = ShelfHandleSpec.label(
            .text("1", tinted: true),
            font: NSFont.systemFont(ofSize: 8)
        )
        let view = view()
        view.render(spec(hovered: true, label: label), animated: true)
        #expect(spec(hovered: true, label: label).labelExtra == 0)
        #expect(view.plate.frame == view.bounds)
    }
}
