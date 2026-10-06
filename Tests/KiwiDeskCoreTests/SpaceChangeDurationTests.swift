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
                == SpaceSlidePlan.response
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

    private func pressedPlay(
        pace: Double
    ) throws -> (SpaceSlideOverlay.Play, CFTimeInterval) {
        let clock = Clock()
        let overlay = SpaceSlideOverlay()
        overlay.present = { _ in }
        overlay.reduceMotion = { false }
        overlay.clock = { clock.now }
        defer { overlay.end() }
        let pressed = overlay.press(
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
        let play = try #require(overlay.play)
        let fade = try #require(
            play.fader.animation(forKey: "out") as? CABasicAnimation
        )
        #expect(abs(fade.duration - SpaceSlidePlan.fadeOut * pace) < 1e-9)
        #expect(
            abs(play.liftAt - pressed.landAt - SpaceSlidePlan.landMargin)
                < 1e-9
        )
        return (play, pressed.landAt)
    }

    /// A doubled pace doubles the spring and the fades; the strip
    /// still waits the parks' fixed delay.
    @Test("the pace scales the strip and the fades, not the waits")
    func paceScalesTheSlide() throws {
        let (base, baseLand) = try pressedPlay(pace: 1)
        let (slow, slowLand) = try pressedPlay(pace: 2)
        #expect(base.motion.response == SpaceSlidePlan.response)
        #expect(slow.motion.response == 2 * SpaceSlidePlan.response)
        #expect(slow.motion.begin == 100 + SpaceSlidePlan.stripDelay)
        #expect(base.motion.begin == slow.motion.begin)
        let baseTravel = baseLand - base.motion.begin
        let slowTravel = slowLand - slow.motion.begin
        #expect(abs(slowTravel - 2 * baseTravel) < 0.011)
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
        #expect(play.motion.response == 2 * SpaceSlidePlan.response)
    }
}
