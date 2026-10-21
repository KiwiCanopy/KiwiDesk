import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Which focus change owes the leave fade, and its settings
/// (#2417): only a tracked window still on a shown Space, at the
/// look's duration and curve; the two verbs and the stored group
/// take the ruled band and spellings.
@Suite("KiwiVision leaving window")
@MainActor
struct KiwiVisionLeavingTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-leave-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        core.eventLoop.ownKeyWindow = { nil }
        core.retile()
        return core
    }

    @Test("a shown window left takes the look's fade")
    func shownWindowFades() throws {
        let core = makeCore()
        _ = core.execute("kiwivision.toggle")
        _ = core.execute(
            "kiwivision.set_fade_curve",
            args: [.string("ease_in")]
        )
        let leaving = try #require(
            core.visionLeaving(from: w1.raw, to: w2.raw)
        )
        #expect(leaving.duration == 0.3)
        #expect(leaving.curve == .easeIn)
    }

    @Test("off, a duration of 0 or the same window owe nothing")
    func nothingOwed() {
        let core = makeCore()
        #expect(core.visionLeaving(from: w1.raw, to: w2.raw) == nil)
        _ = core.execute("kiwivision.toggle")
        #expect(core.visionLeaving(from: w1.raw, to: w1.raw) == nil)
        #expect(core.visionLeaving(from: nil, to: w2.raw) == nil)
        _ = core.execute("kiwivision.set_fade_duration", args: [.number(0)])
        #expect(core.visionLeaving(from: w1.raw, to: w2.raw) == nil)
    }

    @Test("a window on no shown Space owes nothing: a switch is instant")
    func hiddenSpaceIsInstant() {
        let core = makeCore()
        _ = core.execute("kiwivision.toggle")
        _ = core.execute("move_to_space", args: [.string("9")])
        let moved = core.state.workspaces.space(of: w1)
        let hidden = core.state.workspaces.space(of: w2)
        // Whichever window the move took, it now sits off screen.
        let gone = moved?.raw == "9" ? w1 : w2
        #expect(moved != hidden)
        #expect(core.visionLeaving(from: gone.raw, to: nil) == nil)
    }

    /// The wiring: a real focus change reaches the plate as one
    /// fade of the window left, and a Space switch reaches it as
    /// none.
    @Test("a focus change fades through the real path; a switch doesn't")
    func wiring() throws {
        let core = makeCore()
        core.vision.reduceMotion = { false }
        // A frame on the main screen: the fade draws where the window
        // left lies.
        for id in [w1, w2] {
            core.state.apply(
                .windowMoved(
                    id,
                    CGRect(x: 100, y: 100, width: 300, height: 200)
                )
            )
        }
        _ = core.execute("kiwivision.toggle")
        core.state.apply(.windowFocused(w1))
        core.updateVision()
        let plates = core.vision.plates.values.compactMap {
            $0 as? InertVisionPlate
        }
        #expect(!plates.isEmpty)
        let before = plates.flatMap(\.fades).count
        core.state.apply(.windowFocused(w2))
        #expect(core.visionTarget().target == w2.raw)
        core.updateVision()
        let fades = plates.flatMap(\.fades)
        #expect(fades.count == before + 1)
        #expect(fades.last?.window == w1.raw)

        _ = core.execute("move_to_space", args: [.string("9")])
        _ = core.execute("focus_space", args: [.string("9")])
        let after = plates.flatMap(\.fades)
        #expect(after.count == fades.count)
    }

    /// The wiring reads the hold before the settle that may end it.
    @Test("leaving a held window fades nothing through the real path")
    func heldWindowWiring() {
        let core = makeCore()
        core.vision.reduceMotion = { false }
        for id in [w1, w2] {
            core.state.apply(
                .windowMoved(
                    id,
                    CGRect(x: 100, y: 100, width: 300, height: 200)
                )
            )
        }
        _ = core.execute("kiwivision.toggle")
        core.state.apply(.windowFocused(w1))
        core.updateVision()
        let plates = core.vision.plates.values.compactMap {
            $0 as? InertVisionPlate
        }
        let before = plates.flatMap(\.fades).count
        core.vision.hold = VisionHold(window: w1)
        core.state.apply(.windowFocused(w2))
        core.updateVision()
        #expect(plates.flatMap(\.fades).count == before)
    }

    @Test("a non-finite duration reads as the default")
    func nonFiniteDuration() {
        let fallback = AppWideSettings().visionFadeDuration
        #expect(AppWideSettings.clampedFade(.nan) == fallback)
        #expect(AppWideSettings.clampedFade(.infinity) == fallback)
        #expect(AppWideSettings.clampedFade(450.4) == 450)
    }

    @Test("a window a lens held was hazed already: no fade")
    func heldWindowOwesNothing() {
        let core = makeCore()
        _ = core.execute("kiwivision.toggle")
        #expect(
            core.visionLeaving(from: w1.raw, to: w2.raw, heldBefore: w1.raw)
                == nil
        )
    }

    @Test("the verbs take the ruled band and spellings")
    func verbs() {
        let core = makeCore()
        #expect(
            core.execute("kiwivision.set_fade_duration", args: [.number(1000)])
                .isSuccess
        )
        #expect(core.appWide.visionFadeDuration == 1000)
        #expect(
            !core.execute(
                "kiwivision.set_fade_duration",
                args: [.number(1001)]
            ).isSuccess
        )
        #expect(
            !core.execute("kiwivision.set_fade_duration", args: [.number(-1)])
                .isSuccess
        )
        // A huge number is refused, never converted (it would trap).
        #expect(
            !core.execute(
                "kiwivision.set_fade_duration",
                args: [.number(1e300)]
            ).isSuccess
        )
        #expect(
            core.execute(
                "kiwivision.set_fade_curve",
                args: [.string("linear")]
            ).isSuccess
        )
        #expect(core.appWide.visionFadeCurve == .linear)
        #expect(
            !core.execute(
                "kiwivision.set_fade_curve",
                args: [.string("bounce")]
            ).isSuccess
        )
    }

    @Test("a lens table clamps a huge duration instead of trapping")
    func lensClamps() throws {
        let json =
            #"{"name":"R","fade_duration":1e300,"fade_curve":"ease_in"}"#
        let lens = try JSONDecoder().decode(
            VisionLens.self,
            from: Data(json.utf8)
        )
        #expect(lens.overrides.fadeDuration == 1000)
        #expect(lens.overrides.fadeCurve == .easeIn)
    }

    @Test("the stored group clamps the duration and keeps the curve")
    func storedGroup() throws {
        var group = AppWideSettings.Vision()
        group.fadeDuration = 1e300
        group.fadeCurve = .easeInOut
        let settings = try #require(
            AppWideSettings(
                refusal: AppWideSettings.Refusal(),
                quit: nil,
                vision: group
            )
        )
        #expect(settings.visionFadeDuration == 1000)
        #expect(settings.visionFadeCurve == .easeInOut)
        let data = try JSONEncoder().encode(settings.vision)
        let back = try JSONDecoder().decode(
            AppWideSettings.Vision.self,
            from: data
        )
        #expect(back.fadeDuration == 1000)
        #expect(back.fadeCurve == .easeInOut)
        let keys = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(keys["fade_duration"] != nil)
        #expect(keys["fade_curve"] as? String == "ease_in_out")
    }
}
