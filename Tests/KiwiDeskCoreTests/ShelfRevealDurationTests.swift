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

    /// The reveal's switch is its "instant" (#3236): off, every
    /// style lands at once and the mark swaps; the bands hold no 0,
    /// so a value below one rises to its floor.
    @Test("Off is instant, and a 0 rises to the band")
    func offIsInstant() {
        var animations = AnimationSettings()
        let reveal = AnimationSettings.revealDurationBand
        let expand = AnimationSettings.expandDurationBand
        animations.revealDurationMS = 0
        #expect(animations.revealDurationMS == reveal.lowerBound)
        animations.expandDurationMS = 0
        #expect(animations.expandDurationMS == expand.lowerBound)
        #expect(animations.revealSeconds == 0.15)
        animations.onReveal = false
        #expect(animations.revealSeconds == 0)
        #expect(animations.revealDurationMS == reveal.lowerBound)
        for kind in [BarMotion.RevealKind.slide, .grow, .unfold, .fade] {
            let content = NSView(frame: Self.plate)
            let items = NSView(frame: Self.plate)
            let span = BarMotion.playReveal(
                content,
                items: items,
                path: path(kind, length: animations.revealSeconds),
                entering: true
            )
            #expect(span == 0)
            #expect(content.layer?.animationKeys() == nil, "\(kind)")
        }
        let saved = BarMotion.revealLength
        BarMotion.revealLength = animations.revealSeconds
        defer { BarMotion.revealLength = saved }
        let mark = NSView()
        BarMotion.fadeMark(mark, showing: false, reveal: .slide)
        #expect(mark.alphaValue == 0)
        #expect(mark.layer?.animationKeys() == nil)
    }

    @Test("set_on_reveal reaches the bars; a 0 length is refused")
    func verbs() {
        let saved = BarMotion.revealLength
        defer { BarMotion.revealLength = saved }
        let core = makeTestCore()
        #expect(
            core.execute("animations.set_on_reveal", args: [.bool(false)])
                .isSuccess
        )
        #expect(!core.tiler.settings.animations.onReveal)
        #expect(BarMotion.revealLength == 0)
        for verb in [
            "animations.set_reveal_duration",
            "animations.set_expand_duration",
        ] {
            let reply = core.execute(verb, args: [.number(0)])
            #expect(!reply.isSuccess, "\(verb)")
        }
        #expect(core.tiler.settings.animations.revealDurationMS == 300)
        #expect(core.tiler.settings.animations.expandDurationMS == 750)
        core.execute("animations.set_on_reveal", args: [.bool(true)])
        #expect(BarMotion.revealLength == 0.3)
    }
}
