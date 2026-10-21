import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// Every reveal style plays inside one length, the user's
/// `animations.reveal_duration`, and a retract inside
/// `AnimationSettings.retractShare` of it (owner ruling,
/// 2026-10-21). Main-actor spend: a handful of unwindowed views.
@Suite("Shelf reveal duration")
@MainActor
struct ShelfRevealDurationTests {
    private static let mark = CGRect(x: 100, y: 0, width: 60, height: 8)
    private static let plate = CGRect(x: 20, y: 0, width: 360, height: 40)

    private func path(
        _ kind: BarMotion.RevealKind,
        length: TimeInterval
    ) -> BarMotion.RevealPath {
        BarMotion.RevealPath(
            kind: kind,
            offset: CGVector(dx: 0, dy: -40),
            origin: Self.mark,
            plate: Self.plate,
            plateRadius: 10,
            length: length
        )
    }

    /// When the last animation `layers` carry ends, from `start`:
    /// what is INSTALLED, never the length `playReveal` reports.
    private func lastEnd(
        of layers: [CALayer?],
        from start: CFTimeInterval
    ) -> TimeInterval {
        layers.compactMap { $0?.animation(forKey: BarMotion.revealKey) }
            .map { ($0.beginTime - start) + $0.duration / Double($0.speed) }
            .max() ?? 0
    }

    @Test("Every style lands at the user's length, a retract sooner")
    func everyStyleFitsTheLength() {
        let kinds: [BarMotion.RevealKind] = [
            .slide, .grow, .unfold, .spread, .fade,
        ]
        for kind in kinds {
            for length in [0.15, 0.3, 0.8] {
                for entering in [true, false] {
                    let content = NSView(frame: Self.plate)
                    let items = NSView(frame: Self.plate)
                    let box = GlassBoxHost(frame: Self.plate)
                    box.wantsLayer = true
                    items.addSubview(box)
                    let start = CACurrentMediaTime()
                    let reported = BarMotion.playReveal(
                        content,
                        items: items,
                        path: path(kind, length: length),
                        entering: entering
                    )
                    let target =
                        entering
                        ? length : length * AnimationSettings.retractShare
                    let ran = lastEnd(
                        of: [content.layer, items.layer, box.layer],
                        from: start
                    )
                    #expect(abs(reported - target) < 1e-9, "\(kind)")
                    // The landing removes the motion at `reported`:
                    // what runs ends there, never past it — a spread's
                    // nearer box sooner, its length being the
                    // farthest box's.
                    #expect(ran < target + 0.02, "\(kind) \(ran)")
                    if kind != .spread {
                        #expect(ran > target - 0.02, "\(kind) \(ran)")
                    }
                }
            }
        }
    }

    @Test("A longer length slows the motion's own clock")
    func lengthSetsTheSpeed() throws {
        let content = NSView(frame: Self.plate)
        let items = NSView(frame: Self.plate)
        BarMotion.playReveal(
            content,
            items: items,
            path: path(.slide, length: BarMotion.revealSlide * 2),
            entering: true
        )
        let slide = try #require(
            content.layer?.animation(forKey: BarMotion.revealKey)
        )
        #expect(abs(Double(slide.speed) - 0.5) < 1e-6)
    }

    @Test("The reveal duration is stored, clamped and set by its verb")
    func storedAndClamped() throws {
        var animations = AnimationSettings()
        #expect(animations.revealDurationMS == 300)
        let band = AnimationSettings.revealDurationBand
        animations.revealDurationMS = band.upperBound + 1
        #expect(animations.revealDurationMS == band.upperBound)
        animations.revealDurationMS = band.lowerBound - 1
        #expect(animations.revealDurationMS == band.lowerBound)
        let data = try JSONEncoder().encode(animations)
        let json = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(json["reveal_duration"] as? Int == band.lowerBound)
        let core = makeTestCore()
        #expect(
            core.execute(
                "animations.set_reveal_duration",
                args: [.number(500)]
            ).isSuccess
        )
        #expect(core.tiler.settings.animations.revealDurationMS == 500)
    }

    /// 0 is no animation (owner ruling, 2026-10-21): every style
    /// lands at once, the mark swaps, and a value between 0 and the
    /// band rises to its floor, so nothing blinks.
    @Test("0 is instant, and the gap below the band rises to it")
    func zeroIsInstant() {
        var animations = AnimationSettings()
        let reveal = AnimationSettings.revealDurationBand
        let expand = AnimationSettings.expandDurationBand
        animations.revealDurationMS = 0
        #expect(animations.revealDurationMS == 0)
        animations.revealDurationMS = 1
        #expect(animations.revealDurationMS == reveal.lowerBound)
        animations.expandDurationMS = 0
        #expect(animations.expandDurationMS == 0)
        #expect(animations.expandSeconds == 0)
        animations.expandDurationMS = expand.lowerBound - 1
        #expect(animations.expandDurationMS == expand.lowerBound)
        for kind in [BarMotion.RevealKind.slide, .grow, .unfold, .fade] {
            let content = NSView(frame: Self.plate)
            let items = NSView(frame: Self.plate)
            let span = BarMotion.playReveal(
                content,
                items: items,
                path: path(kind, length: 0),
                entering: true
            )
            #expect(span == 0)
            #expect(content.layer?.animationKeys() == nil, "\(kind)")
        }
        let saved = BarMotion.revealLength
        BarMotion.revealLength = 0
        defer { BarMotion.revealLength = saved }
        let mark = NSView()
        BarMotion.fadeMark(mark, showing: false, reveal: .slide)
        #expect(mark.alphaValue == 0)
        #expect(mark.layer?.animationKeys() == nil)
    }

    /// Settings' stepper walks 0 → floor → … and back, never into
    /// the gap; a typed value in the gap rises to the floor.
    @Test("The stepper skips the gap below the band")
    func stepperSkipsTheGap() {
        let band = AnimationSettings.revealDurationBand
        let step = AnimationSettings.revealDurationStep
        let next = { (new: Int, current: Int) in
            AnimationSettings.stepped(
                new,
                from: current,
                band: band,
                step: step
            )
        }
        #expect(next(step, 0) == band.lowerBound)
        #expect(next(band.lowerBound - step, band.lowerBound) == 0)
        #expect(next(band.lowerBound + step, band.lowerBound) == 200)
        #expect(next(100, 300) == band.lowerBound)
        #expect(next(0, 300) == 0)
    }
}
