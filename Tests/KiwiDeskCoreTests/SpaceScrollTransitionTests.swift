import Foundation
import Testing

@testable import KiwiDeskCore

/// `space.scroll_transition` in `gui.json` (#2971): its own leaf of
/// the `space` group, Slide where a file carries none whatever
/// `space.transition` says, and written by its verb alone.
@Suite("Space scroll transition stored shape (#2971)")
@MainActor
struct SpaceScrollTransitionTests {
    private func encoded(
        _ edit: (inout AppWideSettings) -> Void
    ) throws -> [String: Any] {
        var config = GuiConfig()
        var value = AppWideSettings()
        edit(&value)
        config.appWide = value
        return try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(config)
            ) as? [String: Any]
        )
    }

    private func decoded(_ root: [String: Any]) throws -> GuiConfig {
        try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONSerialization.data(withJSONObject: root)
        )
    }

    @Test("gui.json carries the pick and reads it back")
    func storedShape() throws {
        let root = try encoded { $0.spaceScrollTransition = .show }
        let group = try #require(root["space"] as? [String: Any])
        expectEqual(group["scroll_transition"] as? String, "show")
        expectEqual(group["transition"] as? String, "slide")
        #expect(try decoded(root).appWide?.spaceScrollTransition == .show)
    }

    /// The owner's ruling: nobody had a scroll choice to make.
    @Test(
        "a stored transition is not carried over",
        arguments: ["none", "show"]
    )
    func notCarriedOver(stored: String) throws {
        var root = try encoded { _ in }
        root["space"] = ["transition": stored]
        let back = try #require(try decoded(root).appWide)
        expectEqual(back.spaceTransition.rawValue, stored)
        expectEqual(back.spaceScrollTransition, .slide)
    }

    /// Below the #2524 floor too: the cue crosses to the transition
    /// and stops there.
    @Test("the cue's crossing leaves the scroll step on Slide")
    func cueCrossingStops() throws {
        var root = try encoded { _ in }
        root["space"] = ["cue": false]
        root["format"] = 13
        let out = try #require(
            ConfigMigration.migrated(
                JSONSerialization.data(withJSONObject: root)
            )
        )
        let back = try #require(
            JSONDecoder().decode(GuiConfig.self, from: out).appWide
        )
        expectEqual(back.spaceTransition, SpaceTransition.none)
        expectEqual(back.spaceScrollTransition, .slide)
    }

    /// A current file carrying the key is not rewritten.
    @Test("a current file with the key needs no migration")
    func currentFileIsLeftAlone() throws {
        let root = try encoded { $0.spaceScrollTransition = .none }
        expectEqual(root["format"] as? Int, GuiConfig.currentFormat)
        let data = try JSONSerialization.data(withJSONObject: root)
        #expect(ConfigMigration.migrated(data) == nil)
    }

    @Test("the verb writes the running value alone")
    func verbWrites() {
        let core = makeTestCore()
        for style in SpaceTransition.allCases {
            let reply = core.execute(
                "set_space_scroll_transition",
                args: [.string(style.rawValue)]
            )
            #expect(reply.isSuccess)
            expectEqual(core.appWide.spaceScrollTransition, style)
            expectEqual(core.appWide.spaceTransition, .slide)
        }
        #expect(
            !core.execute(
                "set_space_scroll_transition",
                args: [.string("fade")]
            ).isSuccess
        )
    }

    @Test("set_space_transition leaves the scroll step's pick")
    func otherVerbLeavesIt() {
        let core = makeTestCore()
        core.execute("set_space_transition", args: [.string("none")])
        expectEqual(core.appWide.spaceTransition, SpaceTransition.none)
        expectEqual(core.appWide.spaceScrollTransition, .slide)
    }

    @Test("the intent's input picks which value is read")
    func readingFollowsTheInput() {
        let core = makeTestCore()
        core.spaceSlide.reduceMotion = { false }
        core.setAppWide(persisting: false) {
            $0.spaceTransition = .none
            $0.spaceScrollTransition = .show
        }
        func intent(scrolled: Bool) -> SpaceSlideIntent {
            SpaceSlideIntent(
                display: DisplayID(1),
                leaving: nil,
                step: 1,
                scrolled: scrolled
            )
        }
        #expect(
            core.drawnSpaceTransition(for: intent(scrolled: true)) == .show
        )
        #expect(
            core.drawnSpaceTransition(for: intent(scrolled: false))
                == SpaceTransition.none
        )
        // Reduce Motion wins after the pick: Slide draws the plate.
        core.spaceSlide.reduceMotion = { true }
        core.setAppWide(persisting: false) {
            $0.spaceScrollTransition = .slide
        }
        #expect(
            core.drawnSpaceTransition(for: intent(scrolled: true)) == .show
        )
    }
}
