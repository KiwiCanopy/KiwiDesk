import Foundation
import Testing

@testable import KiwiDeskCore

/// `stack.toggle_stack_position([space])` (#2771): the opposite
/// of the side the Space draws now, filed as session state for the
/// Desktop shown — never a setting. These cores read no SkyLight,
/// so every flip lands in the one Desktop-less entry.
@Suite("Stack toggle position (#2771)", .serialized)
@MainActor
struct StackTogglePositionTests {
    private let verb = "stack.toggle_stack_position"

    private func drawn(
        _ core: KiwiCore,
        _ space: SpaceID = "1"
    ) -> StackParams.StackPosition {
        core.drawnStackPosition(of: space)
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
        #expect(core.execute(verb).isSuccess)
        #expect(drawn(core) == .left)
        #expect(core.stackFlip(of: "1") == .left)
        #expect(core.execute(verb).isSuccess)
        #expect(drawn(core) == .right)
        #expect(core.stackFlip(of: "1") == nil)
        #expect(core.desktopMemory.stackFlips.isEmpty)
    }

    @Test("the flip writes no setting, and revert_settings leaves it")
    func writesNoSetting() throws {
        let core = try KeepFixture.core()
        let before = core.tiler.settings
        #expect(core.execute(verb).isSuccess)
        #expect(core.tiler.settings == before)
        #expect(core.tiler.settings.stack.override["1"] == nil)
        #expect(core.unsavedLiveSettings() == nil)
        _ = core.execute("stack.set_master_count", args: [.number(3)])
        let unsaved = try #require(core.unsavedLiveSettings())
        let ids = Array(unsaved.leaves.keys)
        #expect(ids.allSatisfy { !$0.contains("stack_position") })
        #expect(
            core.execute(
                KiwiCore.revertSettingsCommand,
                args: ids.map(JSONValue.string)
            ).isSuccess
        )
        #expect(core.unsavedLiveSettings() == nil)
        #expect(drawn(core) == .left)
    }

    @Test("the flip reads the drawn side, override before global")
    func readsTheDrawnSide() throws {
        let core = try KeepFixture.core()
        _ = core.execute(
            "stack.set_stack_position",
            args: [.string("bottom")]
        )
        #expect(core.execute(verb).isSuccess)
        #expect(drawn(core) == .top)
        _ = core.execute(
            "stack.set_stack_position_override",
            args: [.string("1"), .string("left")]
        )
        #expect(drawn(core) == .left)
        #expect(core.execute(verb).isSuccess)
        #expect(drawn(core) == .right)
    }

    @Test("an id names another Space; an unknown one is refused")
    func namedSpace() throws {
        let core = try KeepFixture.core()
        core.state.workspaces.ensureSpace("2", mode: .stack)
        #expect(core.execute(verb, args: [.string("2")]).isSuccess)
        #expect(drawn(core, "2") == .left)
        #expect(drawn(core) == .right)
        let refused = core.execute(verb, args: [.string("9")])
        #expect(!refused.isSuccess)
        #expect(refused.error == "unknown space: 9")
        #expect(core.stackFlip(of: "9") == nil)
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
        let space = try #require(core.state.workspaces["1"])
        let params = core.tiler.settings.resolvedStack(
            for: space,
            flip: core.stackFlip(of: "1")
        )
        #expect(params.stackPosition == .left)
        #expect(params.masterRatio == 0.7)
        #expect(params.masterCount == 2)
        let over = try #require(core.tiler.settings.stack.override["1"])
        #expect(over.stackPosition == nil)
    }

    @Test("get_state names the side a Stack Space draws")
    func getStateReportsTheDrawnSide() throws {
        let core = try KeepFixture.core()
        core.state.workspaces.ensureSpace("1", mode: .stack)
        core.setSpaceMode("1", .stack)
        func reported() -> String? {
            guard case .object(let root) = core.stateJSON(),
                case .array(let spaces)? = root["spaces"]
            else { return nil }
            for case .object(let space) in spaces
            where space["id"]?.stringValue == "1" {
                return space["stack_position"]?.stringValue
            }
            return nil
        }
        #expect(reported() == "right")
        #expect(core.execute(verb).isSuccess)
        #expect(reported() == "left")
    }
}
