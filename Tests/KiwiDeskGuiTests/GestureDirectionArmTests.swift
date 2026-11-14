import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A direction's own action (#3321): App… and Lua… write that arm
/// alone, blank Lua drops it, and the save pill names the direction
/// whose action changed rather than "Per direction" twice.
@Suite("Gesture direction arms (#3321)")
@MainActor
struct GestureDirectionArmTests {
    private let input = GestureInput.swipe3
    private var family: GestureFamily { input.families[0] }
    private var key: GestureKey { GestureKey(input, [.control, .option]) }
    private let app = LuaAction(
        lua: KeybindingCatalog.appCommand("com.apple.Safari"),
        kind: .application,
        meta: KeyBindingMeta(desc: "Safari")
    )

    @Test("an app on one direction keeps every other arm")
    func appKeepsTheOthers() throws {
        let saved = GestureListEdits.arm(
            app,
            toward: .left,
            of: .family(family),
            on: input
        )
        let arms = try #require(
            GestureListEdits.arms(of: saved, on: input)
        )
        let prefill = GestureListEdits.prefill(family, on: input)
        #expect(arms[.left] == app)
        for direction in input.directions where direction != .left {
            #expect(arms[direction] == prefill[direction])
        }
    }

    @Test("blank Lua drops its arm, and the family's step folds back")
    func blankDropsTheArm() throws {
        let split = GestureListEdits.arm(
            app,
            toward: .left,
            of: .family(family),
            on: input
        )
        let blank = LuaAction(lua: " ", kind: .custom)
        let dropped = GestureListEdits.arm(
            blank,
            toward: .left,
            of: split,
            on: input
        )
        let arms = try #require(
            GestureListEdits.arms(of: dropped, on: input)
        )
        #expect(arms[.left] == nil)
        #expect(arms.count == input.directions.count - 1)
        let step = try #require(
            GestureListEdits.prefill(family, on: input)[.left]
        )
        let back = GestureListEdits.arm(
            step,
            toward: .left,
            of: dropped,
            on: input
        )
        #expect(back == .family(family))
    }

    @Test("a last blank arm stays, refused as no action")
    func lastBlankIsRefused() {
        let blank = LuaAction(lua: "", kind: .custom)
        let saved = GestureListEdits.arm(
            blank,
            toward: .up,
            of: nil,
            on: input
        )
        #expect(saved.refusal(on: key) == .emptyAction)
    }

    @Test("the save pill names the direction whose arm changed")
    func diffNamesTheDirection() throws {
        LocalizationManager.shared.select("en")
        var old = GestureMap()
        old[key] = .bound(.family(family))
        var new = GestureMap()
        new[key] = .bound(
            GestureListEdits.arm(
                app,
                toward: .left,
                of: .family(family),
                on: input
            )
        )
        let rows = SettingsValueReadout.gestureRows(old: old, new: new)
        let row = try #require(rows.first)
        #expect(rows.count == 1)
        #expect(
            row.label.contains(GestureListWords.direction(.left))
        )
        #expect(row.newValue == "Safari")
    }
}
