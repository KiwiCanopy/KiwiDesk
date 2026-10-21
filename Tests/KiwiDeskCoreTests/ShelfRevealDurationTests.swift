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

    @Test("Every style lands at the user's length, a retract sooner")
    func everyStyleFitsTheLength() {
        let kinds: [BarMotion.RevealKind] = [
            .slide, .grow, .unfold, .spread, .fade,
        ]
        for kind in kinds {
            for length in [0.15, 0.3, 0.8] {
                let content = NSView(frame: Self.plate)
                let items = NSView(frame: Self.plate)
                let entering = BarMotion.playReveal(
                    content,
                    items: items,
                    path: path(kind, length: length),
                    entering: true
                )
                #expect(abs(entering - length) < 1e-9, "\(kind)")
                let leaving = BarMotion.playReveal(
                    content,
                    items: items,
                    path: path(kind, length: length),
                    entering: false
                )
                let share = AnimationSettings.retractShare
                #expect(abs(leaving - length * share) < 1e-9, "\(kind)")
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
}
