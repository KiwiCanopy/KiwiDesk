import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The split editor's edits by axis (#1873 ▸ Ruling 2026-11-15):
/// the level follows the picks, a family folds an axis back, and
/// an action on one direction splits only its axis.
@Suite("Gesture axis edits")
struct GestureAxisEditsTests {
    private let other = LuaAction(lua: "kiwihub.show(\"desktops\")")

    @Test("an action on one direction splits only its axis")
    func armSplitsItsAxis() {
        let saved = GestureListEdits.arm(
            other,
            toward: .up,
            of: .family(.space),
            on: .swipe3
        )
        guard case .split(let split) = saved else {
            Issue.record("one direction's action should split the row")
            return
        }
        #expect(split.axes == [.leftRight: .space])
        #expect(split.arms[.up] == other)
        #expect(split.arms[.down]?.lua == GestureFamily.space.lua(.down))
    }

    @Test("a family on an axis folds it back, both axes fold to whole")
    func familyFoldsTheAxis() {
        let split = GestureAction.split(
            GestureSplit(axes: [.leftRight: .space], arms: [.up: other])
        )
        let perAxis = GestureListEdits.axis(
            .upDown,
            family: .display,
            of: split,
            on: .swipe3
        )
        #expect(
            perAxis
                == .split(
                    GestureSplit(
                        axes: [.leftRight: .space, .upDown: .display],
                        arms: [:]
                    )
                )
        )
        let whole = GestureListEdits.axis(
            .upDown,
            family: .space,
            of: split,
            on: .swipe3
        )
        #expect(whole == .family(.space))
    }

    @Test("a wheel keeps folding whole, never by axis")
    func wheelHasNoAxes() {
        var arms = GestureListEdits.prefill(.walk, on: .wheel)
        arms[.up] = other
        guard
            case .split(let split) = GestureListEdits.folded(arms, on: .wheel)
        else {
            Issue.record("a changed arm should split the wheel")
            return
        }
        #expect(split.axes.isEmpty)
        #expect(!GestureListEdits.splitsByAxis(.wheel))
        #expect(GestureListEdits.splitsByAxis(.swipe3))
    }
}
