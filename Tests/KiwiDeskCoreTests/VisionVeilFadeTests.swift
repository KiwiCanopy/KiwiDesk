import AppKit
import Testing

@testable import KiwiDeskCore

/// The veil's leave fade (#2417): while a region fades, the dim and
/// the blur each take their own mask — the resting shape less the
/// region, plus the region fading in — and the content's own mask
/// stands down; a re-mask meanwhile moves the resting shape.
@Suite("KiwiVision veil fade")
@MainActor
struct VisionVeilFadeTests {
    private func veil() -> VisionVeil {
        let veil = VisionVeil()
        veil.view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        veil.view.layer?.frame = veil.view.bounds
        veil.update(
            size: CGSize(width: 200, height: 100),
            dim: 0.5,
            blur: true,
            cornerRadius: 0
        )
        return veil
    }

    private let region = CGPath(
        rect: CGRect(x: 10, y: 10, width: 40, height: 30),
        transform: nil
    )

    @Test("a fade masks the dim and the blur apart")
    func fadeTakesBothMasks() throws {
        let veil = veil()
        veil.mask(
            CGPath(
                rect: CGRect(x: 0, y: 0, width: 150, height: 100),
                transform: nil
            )
        )
        veil.fadeIn(
            region,
            duration: 0.6,
            timing: VisionFadeCurve.easeOut.timing
        )
        let fade = try #require(veil.fade)
        #expect(veil.view.layer?.mask == nil)
        #expect(veil.dimLayer.mask === fade.dimMask)
        #expect(veil.blurHost.layer?.mask === fade.blurMask)
        #expect(fade.regions.count == 1)
        let animated = try #require(
            fade.regions.first?.dim.animation(forKey: "fade")
                as? CABasicAnimation
        )
        #expect(animated.fromValue as? Float == 0)
        #expect(animated.toValue as? Float == 1)
        #expect(animated.duration == 0.6)
        #expect(
            fade.dimBase.path?.contains(CGPoint(x: 20, y: 20)) == false
        )
        #expect(
            fade.dimBase.path?.contains(CGPoint(x: 100, y: 50)) == true
        )
    }

    @Test("a re-mask during a fade moves the resting shape only")
    func reshapeDuringFade() throws {
        let veil = veil()
        veil.fadeIn(
            region,
            duration: 0.6,
            timing: VisionFadeCurve.linear.timing
        )
        let narrow = CGPath(
            rect: CGRect(x: 0, y: 0, width: 80, height: 100),
            transform: nil
        )
        veil.mask(narrow)
        let fade = try #require(veil.fade)
        #expect(veil.view.layer?.mask == nil)
        #expect(veil.restingPath == narrow)
        #expect(
            fade.dimBase.path?.contains(CGPoint(x: 120, y: 50)) == false
        )
    }

    @Test("a second fade runs beside the first, and 0 fades nothing")
    func fadesStack() throws {
        let veil = veil()
        veil.fadeIn(region, duration: 0, timing: .init(name: .linear))
        #expect(veil.fade == nil)
        veil.fadeIn(region, duration: 0.6, timing: .init(name: .linear))
        let other = CGPath(
            rect: CGRect(x: 100, y: 10, width: 40, height: 30),
            transform: nil
        )
        veil.fadeIn(other, duration: 0.6, timing: .init(name: .linear))
        #expect(try #require(veil.fade).regions.count == 2)
    }
}
