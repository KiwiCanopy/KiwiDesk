import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The plate slide's pace (#1931): `animations.space_change_duration`
/// defaults to the slide's own timing, clamps to its band, is
/// written by its verb, and scales the strip's spring and both
/// fades while the app-latency waits stay fixed. The overlay
/// clauses pin its clock and never order a panel in.
@Suite("Space switch duration (#1931)", .serialized)
@MainActor
struct SpaceChangeDurationTests {
    private final class Clock {
        var now: CFTimeInterval = 100
    }

    @Test("the default is the slide's own timing")
    func defaultIsTodaysTiming() throws {
        let animations = AnimationSettings()
        #expect(
            Double(animations.spaceChangeDurationMS) / 1000
                == SpaceSlidePlan.response(at: 1)
        )
        #expect(animations.spaceSlidePace == 1)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(#"{"animations":{}}"#.utf8)
        )
        #expect(decoded.animations.spaceSlidePace == 1)
    }

    @Test("the wire key is the Lua name with set_ stripped")
    func wireKey() throws {
        var settings = TilingSettings()
        settings.animations.spaceChangeDurationMS = 600
        let data = try JSONEncoder().encode(settings)
        let object =
            try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        let animations = object?["animations"] as? [String: Any]
        #expect(animations?["space_change_duration"] as? Int == 600)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded.animations.spaceChangeDurationMS == 600)
    }

    @Test("the duration clamps to its band on decode and on write")
    func clamp() throws {
        let band = AnimationSettings.spaceChangeDurationBand
        var animations = AnimationSettings()
        animations.spaceChangeDurationMS = band.lowerBound - 1
        #expect(animations.spaceChangeDurationMS == band.lowerBound)
        animations.spaceChangeDurationMS = band.upperBound + 1
        #expect(animations.spaceChangeDurationMS == band.upperBound)
        let json = #"{"animations":{"space_change_duration":5000}}"#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(
            decoded.animations.spaceChangeDurationMS == band.upperBound
        )
    }

    @Test("the verb writes the setting")
    func verbWrites() {
        let core = makeTestCore()
        #expect(
            core.execute(
                "animations.set_space_change_duration",
                args: [.number(450)]
            ).isSuccess
        )
        #expect(core.tiler.settings.animations.spaceChangeDurationMS == 450)
        #expect(
            !core.execute(
                "animations.set_space_change_duration",
                args: [.string("slow")]
            ).isSuccess
        )
    }

    private func makeOverlay(_ clock: Clock) -> SpaceSlideOverlay {
        let overlay = SpaceSlideOverlay()
        overlay.present = { _ in }
        overlay.reduceMotion = { false }
        overlay.clock = { clock.now }
        return overlay
    }

    @discardableResult
    private func press(
        _ overlay: SpaceSlideOverlay,
        pace: Double
    ) -> SpaceSlideOverlay.Pressed {
        overlay.press(
            SpaceSlideOverlay.Press(
                display: DisplayID(1),
                screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
                axis: .horizontal,
                direction: 1,
                outgoing: [],
                holes: [],
                space: SpaceID("2"),
                glass: false,
                pace: pace
            )
        )
    }

    private func fade(
        _ play: SpaceSlideOverlay.Play,
        _ key: String
    ) throws -> CFTimeInterval {
        try #require(
            play.fader.animation(forKey: key) as? CABasicAnimation
        ).duration
    }

    /// The spring the render server plays — not the model beside
    /// it — as its natural frequency.
    private func playedOmega(_ play: SpaceSlideOverlay.Play) throws
        -> CGFloat
    {
        let spring = try #require(
            play.strip.layer?.animation(forKey: "strip")
                as? CASpringAnimation
        )
        return (spring.stiffness / spring.mass).squareRoot()
    }

    /// A doubled pace doubles the spring and the fades; the strip
    /// still waits the parks' fixed delay, and the plates the
    /// landed windows' fixed margin.
    @Test("the pace scales the strip and the fades, not the waits")
    func paceScalesTheSlide() throws {
        var lands: [Double: CFTimeInterval] = [:]
        var begins: [Double: CFTimeInterval] = [:]
        for pace in [1.0, 2.0] {
            let clock = Clock()
            let overlay = makeOverlay(clock)
            defer { overlay.end() }
            let pressed = press(overlay, pace: pace)
            overlay.run(incoming: [], holes: [])
            let play = try #require(overlay.play)
            let response = SpaceSlidePlan.response(at: pace)
            #expect(response == SpaceSlidePlan.response(at: 1) * pace)
            #expect(play.motion.response == response)
            #expect(abs(try playedOmega(play) - 2 * .pi / response) < 1e-6)
            let fadeIn = SpaceSlidePlan.fadeIn(at: 1) * pace
            let fadeOut = SpaceSlidePlan.fadeOut(at: 1) * pace
            #expect(abs(try fade(play, "in") - fadeIn) < 1e-9)
            #expect(abs(try fade(play, "out") - fadeOut) < 1e-9)
            #expect(play.motion.begin == 100 + SpaceSlidePlan.stripDelay)
            #expect(
                abs(play.liftAt - pressed.landAt - SpaceSlidePlan.landMargin)
                    < 1e-9
            )
            lands[pace] = pressed.landAt
            begins[pace] = play.motion.begin
        }
        let base = try #require(lands[1]) - #require(begins[1])
        let slow = try #require(lands[2]) - #require(begins[2])
        #expect(abs(slow - 2 * base) < 0.011)
    }

    /// A press mid-flight at a new pace re-paces the play: the
    /// retargeted spring and the rescheduled lift follow it.
    @Test("a burst press carries its own pace")
    func burstTakesTheNewPace() throws {
        let clock = Clock()
        let overlay = makeOverlay(clock)
        defer { overlay.end() }
        press(overlay, pace: 1)
        overlay.run(incoming: [], holes: [])
        clock.now = try #require(overlay.play?.motion.begin) + 0.1
        press(overlay, pace: 2)
        overlay.run(incoming: [], holes: [])
        let play = try #require(overlay.play)
        #expect(play.pace == 2)
        #expect(play.motion.response == SpaceSlidePlan.response(at: 2))
        #expect(
            abs(try playedOmega(play) - 2 * .pi / play.motion.response)
                < 1e-6
        )
        #expect(
            abs(try fade(play, "out") - 2 * SpaceSlidePlan.fadeOut(at: 1))
                < 1e-9
        )
    }

    /// A press after the landing waits the parks' fixed delay
    /// again, whatever the new pace.
    @Test("a press after the landing keeps the fixed delay")
    func landedPressKeepsTheDelay() throws {
        let clock = Clock()
        let overlay = makeOverlay(clock)
        defer { overlay.end() }
        let first = press(overlay, pace: 1)
        overlay.run(incoming: [], holes: [])
        clock.now = first.landAt + 0.01
        press(overlay, pace: 2)
        let motion = try #require(overlay.play?.motion)
        #expect(motion.begin == clock.now + SpaceSlidePlan.stripDelay)
        #expect(motion.response == SpaceSlidePlan.response(at: 2))
    }

    /// The switch hands the overlay the setting's pace at the press.
    @Test(
        "a switch plays at the configured pace",
        .enabled(if: NSScreen.main != nil)
    )
    func switchReadsThePace() throws {
        let display = try #require(NSScreen.main?.kiwiDisplayID)
        let core = makeTestCore()
        core.tiler.animation.isEnabled = false
        core.tiler.settings.animations.onSpaceChange = true
        core.tiler.settings.animations.spaceChangeDurationMS = 600
        core.spaceSlide.reduceMotion = { false }
        for (id, space): (UInt32, Int) in [(1, 1), (2, 2)] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: WindowID(id), pid: 1, appName: "A")
                )
            )
            core.state.workspaces.add(WindowID(id), to: SpaceID(space))
            core.state.workspaces.assign(SpaceID(space), to: display)
        }
        core.state.workspaces.activate(SpaceID(1))
        core.retile()
        core.execute("focus_space", args: [.string("2")])
        defer { core.endSpaceSlide() }
        let play = try #require(core.spaceSlide.play)
        #expect(play.pace == 2)
        #expect(play.motion.response == SpaceSlidePlan.response(at: 2))
    }
}
