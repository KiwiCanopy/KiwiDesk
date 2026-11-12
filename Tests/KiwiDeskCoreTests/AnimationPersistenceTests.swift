import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory:
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwi-anim-\(UUID().uuidString)"
            )
    )
}

/// The four animation lengths are app-wide (#3237): the verbs keep
/// their names, write the session alone, clamp to their bands, and
/// reach the window engine and the bars; a profile apply never
/// moves them.
@Suite("Animation pace (#3237)", .serialized)
@MainActor
struct AnimationPersistenceTests {
    @Test("the group round-trips through gui.json")
    func roundTrip() throws {
        var config = GuiConfig()
        var wide = AppWideSettings()
        wide.animationDurationMS = 350
        wide.animationRevealDurationMS = 500
        config.appWide = wide
        let data = try JSONEncoder().encode(config)
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.appWide?.animationDurationMS == 350)
        #expect(back.appWide?.animationRevealDurationMS == 500)
        #expect(back.appWide?.animationPaceStored == true)
    }

    @Test("a gui.json from before the group owes the crossing")
    func absenceIsOwed() throws {
        var config = GuiConfig()
        var wide = AppWideSettings()
        wide.animationPaceStored = false
        config.appWide = wide
        let data = try JSONEncoder().encode(config)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(!text.contains("\"animations\""))
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.appWide?.animationPaceStored == false)
    }

    @Test("the verbs write the live app-wide values and the engine")
    func verbsWriteAppWide() {
        let glide = BarMotion.shelfGlide
        let reveal = BarMotion.revealLength
        defer {
            BarMotion.shelfGlide = glide
            BarMotion.revealLength = reveal
        }
        let core = makeCore()
        let verbs: [(String, Int)] = [
            ("animations.set_duration", 400),
            ("animations.set_scroll_duration", 420),
            ("animations.set_expand_duration", 1000),
            ("animations.set_reveal_duration", 500),
        ]
        for (verb, ms) in verbs {
            #expect(core.execute(verb, args: [.number(Double(ms))]).isSuccess)
        }
        #expect(core.appWide.animationDurationMS == 400)
        #expect(core.appWide.animationScrollDurationMS == 420)
        #expect(core.appWide.animationExpandDurationMS == 1000)
        #expect(core.appWide.animationRevealDurationMS == 500)
        #expect(core.tiler.animation.durationMS == 400)
        #expect(core.tiler.animation.scrollDurationMS == 420)
    }

    @Test("the verbs clamp to their bands")
    func verbsClamp() {
        let core = makeCore()
        core.execute("animations.set_duration", args: [.number(10)])
        #expect(core.appWide.animationDurationMS == 50)
        #expect(core.tiler.animation.durationMS == 50)
        core.execute("animations.set_scroll_duration", args: [.number(5000)])
        #expect(core.appWide.animationScrollDurationMS == 1000)
        #expect(core.tiler.animation.scrollDurationMS == 1000)
    }

    @Test("a hand-edited out-of-range group decodes clamped")
    func decodeClamps() throws {
        let data = Data(
            """
            {"refusal":{},"quit":{},"animations":\
            {"duration":5000,"scroll_duration":1,\
            "expand_duration":9,"reveal_duration":9999}}
            """.utf8
        )
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        let wide = try #require(back.appWide)
        #expect(wide.animationDurationMS == 1000)
        #expect(wide.animationScrollDurationMS == 50)
        #expect(wide.animationExpandDurationMS == 500)
        #expect(wide.animationRevealDurationMS == 800)
    }

    @Test("a profile apply leaves the pace alone")
    func applyKeepsPace() throws {
        let core = makeCore()
        core.execute("animations.set_duration", args: [.number(450)])
        try core.profiles.save(
            Profile(
                name: "other",
                monitorSets: [],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        core.execute("load_profile", args: [.string("other")])
        #expect(core.appWide.animationDurationMS == 450)
        #expect(core.tiler.animation.durationMS == 450)
    }
}
