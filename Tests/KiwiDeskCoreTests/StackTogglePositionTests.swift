import Foundation
import Testing

@testable import KiwiDeskCore

/// `stack.toggle_stack_position([space])` (#2771): the opposite
/// side of the Space's resolved position, written into its
/// override as a live change `revert_settings` undoes.
@Suite("Stack toggle position (#2771)", .serialized)
@MainActor
struct StackTogglePositionTests {
    private let verb = "stack.toggle_stack_position"

    private func side(
        _ core: KiwiCore,
        _ space: SpaceID = "1"
    ) -> StackParams.StackPosition? {
        core.tiler.settings.stack.override[space]?.stackPosition
    }

    @Test("every side flips to the one across the master zone")
    func oppositeIsAcross() {
        typealias Side = StackParams.StackPosition
        let pairs: [Side: Side] = [
            .top: .bottom, .bottom: .top, .left: .right, .right: .left,
        ]
        for position in Side.allCases {
            #expect(position.opposite == pairs[position])
            #expect(
                position.opposite.splitsHorizontally
                    == position.splitsHorizontally
            )
        }
    }

    @Test("the focused Space flips, and a second press flips back")
    func focusedSpaceFlipsBack() throws {
        let core = try KeepFixture.core()
        #expect(core.state.workspaces.activeSpace == "1")
        #expect(core.tiler.settings.stack.stackPosition == .right)
        #expect(core.execute(verb).isSuccess)
        #expect(side(core) == .left)
        #expect(core.execute(verb).isSuccess)
        #expect(side(core) == nil)
        #expect(core.tiler.settings.stack.override["1"] == nil)
        #expect(core.tiler.settings.stack.stackPosition == .right)
        #expect(core.unsavedLiveSettings() == nil)
    }

    @Test("the flip reads the resolved side, override before global")
    func readsTheResolvedSide() throws {
        let core = try KeepFixture.core()
        _ = core.execute(
            "stack.set_stack_position",
            args: [.string("bottom")]
        )
        #expect(core.execute(verb).isSuccess)
        #expect(side(core) == .top)
        _ = core.execute(
            "stack.set_stack_position_override",
            args: [.string("1"), .string("left")]
        )
        #expect(core.execute(verb).isSuccess)
        #expect(side(core) == .right)
    }

    @Test("an id names another Space; an unknown one is refused")
    func namedSpace() throws {
        let core = try KeepFixture.core()
        core.state.workspaces.ensureSpace("2", mode: .stack)
        #expect(core.execute(verb, args: [.string("2")]).isSuccess)
        #expect(side(core, "2") == .left)
        #expect(side(core) == nil)
        let refused = core.execute(verb, args: [.string("9")])
        #expect(!refused.isSuccess)
        #expect(refused.error == "unknown space: 9")
        #expect(core.tiler.settings.stack.override["9"] == nil)
    }

    @Test("only the side changes; sizing and other fields stay")
    func sizingStays() throws {
        let core = try KeepFixture.core()
        _ = core.execute(
            "stack.set_master_ratio_override",
            args: [.string("1"), .number(0.7)]
        )
        _ = core.execute(
            "stack.set_master_count_override",
            args: [.string("1"), .number(2)]
        )
        #expect(core.execute(verb).isSuccess)
        let over = try #require(core.tiler.settings.stack.override["1"])
        #expect(over.stackPosition == .left)
        #expect(over.masterRatio == 0.7)
        #expect(over.masterCount == 2)
        #expect(core.execute(verb).isSuccess)
        let back = try #require(core.tiler.settings.stack.override["1"])
        #expect(back.stackPosition == nil)
        #expect(back.masterRatio == 0.7)
        #expect(back.masterCount == 2)
    }

    @Test("the flip is live, unsaved, and revert_settings undoes it")
    func revertUndoes() throws {
        let core = try KeepFixture.core()
        #expect(core.unsavedLiveSettings() == nil)
        #expect(core.execute(verb).isSuccess)
        #expect(side(core) == .left)
        #expect(core.tiler.settings.stack.stackPosition == .right)
        let unsaved = try #require(core.unsavedLiveSettings())
        let ids = Array(unsaved.leaves.keys)
        #expect(ids.count == 1)
        #expect(ids.first?.contains("stack_position") == true)
        #expect(
            core.execute(
                KiwiCore.revertSettingsCommand,
                args: ids.map(JSONValue.string)
            ).isSuccess
        )
        #expect(side(core) == nil)
        #expect(core.unsavedLiveSettings() == nil)
    }
}
