import Foundation
import Testing

@testable import KiwiDeskCore

/// `space.transition` and `space.slide_duration` in `gui.json`
/// (#2524): written beside `desktop.cue` and `mode.cue`,
/// round-tripped, read as the slide at its own pace where a file
/// carries no `space` group, and written by their verbs.
@Suite("Space transition stored shape (#2524)")
@MainActor
struct SpaceTransitionStoredShapeTests {
    @Test("gui.json carries the transition and the pace")
    func storedShape() throws {
        var config = GuiConfig()
        var value = AppWideSettings()
        value.spaceTransition = .none
        value.spaceSlideDuration = 600
        config.appWide = value
        let data = try JSONEncoder().encode(config)
        let root = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        let group = try #require(root["space"] as? [String: Any])
        expectEqual(group["transition"] as? String, "none")
        expectEqual(group["slide_duration"] as? Int, 600)
        #expect(group["cue"] == nil)
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        expectEqual(back.appWide?.spaceTransition, SpaceTransition.none)
        expectEqual(back.appWide?.spaceSlideDuration, 600)
        var older = root
        older["space"] = nil
        let legacy = try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONSerialization.data(withJSONObject: older)
        )
        expectEqual(legacy.appWide?.spaceTransition, .slide)
        #expect(
            legacy.appWide?.spaceSlideDuration
                == AppWideSettings.spaceSlideDefaultMS
        )
    }

    /// The one fallback Core's switch and the Settings rows ask.
    @Test("Slide under Reduce Motion draws Show; nothing else moves")
    func drawnFallback() {
        for style in SpaceTransition.allCases {
            expectEqual(style.drawn(reduceMotion: false), style)
        }
        expectEqual(SpaceTransition.slide.drawn(reduceMotion: true), .show)
        expectEqual(SpaceTransition.show.drawn(reduceMotion: true), .show)
        #expect(
            SpaceTransition.none.drawn(reduceMotion: true)
                == SpaceTransition.none
        )
    }

    @Test("a stored pace outside the band decodes clamped")
    func decodeClamps() throws {
        let band = AppWideSettings.spaceSlideDurationRange
        let json =
            #"{"refusal":{},"space":{"slide_duration":5000}}"#
        let decoded = try JSONDecoder().decode(
            GuiConfig.self,
            from: Data(json.utf8)
        )
        expectEqual(decoded.appWide?.spaceSlideDuration, band.upperBound)
    }

    @Test("the verbs write, clamp and refuse")
    func verbs() {
        let core = makeTestCore()
        for style in SpaceTransition.allCases {
            #expect(
                core.execute(
                    "set_space_transition",
                    args: [.string(style.rawValue)]
                ).isSuccess
            )
            expectEqual(core.appWide.spaceTransition, style)
        }
        #expect(
            !core.execute("set_space_transition", args: [.string("fade")])
                .isSuccess
        )
        #expect(
            core.execute("set_space_slide_duration", args: [.number(450)])
                .isSuccess
        )
        expectEqual(core.appWide.spaceSlideDuration, 450)
        core.execute("set_space_slide_duration", args: [.number(1)])
        #expect(
            core.appWide.spaceSlideDuration
                == AppWideSettings.spaceSlideDurationRange.lowerBound
        )
        #expect(
            !core.execute(
                "set_space_slide_duration",
                args: [.string("slow")]
            ).isSuccess
        )
    }
}
