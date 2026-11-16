import Foundation
import Testing

@testable import KiwiDeskCore

private let hyper: ScrollChord = [.control, .option]

/// A swipe's split below its whole family (#1873 ▸ Ruling
/// 2026-11-15): an axis family beside fixed direction arms, folded
/// to one stored spelling, read through one resolver.
@Suite("Gesture split arms")
struct GestureSplitTests {
    private let overview = LuaAction(lua: "kiwihub.show(\"desktops\")")

    private func decode(_ json: String) throws -> GestureAction {
        try JSONDecoder().decode(
            GestureAction.self,
            from: Data(json.utf8)
        )
    }

    @Test("the fold keeps one spelling per behaviour")
    func foldIsCanonical() {
        // An arm under an axis that has a family is the family's.
        let shadowed = GestureAction.split(
            normalizing: GestureSplit(
                axes: [.leftRight: .space],
                arms: [.left: overview, .up: overview]
            )
        )
        #expect(
            shadowed
                == .split(
                    GestureSplit(
                        axes: [.leftRight: .space],
                        arms: [.up: overview]
                    )
                )
        )
        // Both axes on one family with no arm is that family whole.
        let whole = GestureAction.split(
            normalizing: GestureSplit(
                axes: [.leftRight: .focus, .upDown: .focus],
                arms: [:]
            )
        )
        #expect(whole == .family(.focus))
        // Two families stay per axis.
        let perAxis = GestureSplit(
            axes: [.leftRight: .space, .upDown: .display],
            arms: [:]
        )
        #expect(GestureAction.split(normalizing: perAxis) == .split(perAxis))
        #expect(
            GestureAction.split(
                normalizing: GestureSplit(axes: [:], arms: [:])
            ) == nil
        )
    }

    @Test("a direction resolves to its axis's family or its own arm")
    func stepResolves() {
        let action = GestureAction.split(
            GestureSplit(axes: [.leftRight: .space], arms: [.up: overview])
        )
        #expect(action.step(toward: .left) == .family(.space))
        #expect(action.step(toward: .right) == .family(.space))
        #expect(action.step(toward: .up) == .lua(overview))
        #expect(action.step(toward: .down) == nil)
        #expect(action.step(toward: nil) == nil)
        #expect(
            GestureAction.family(.focus).step(toward: .up) == .family(.focus)
        )
        // A whole family still steps nowhere on a press with no way.
        #expect(GestureAction.family(.focus).step(toward: nil) == nil)
    }

    @Test("an axis family round-trips under split")
    func wire() throws {
        let action = GestureAction.split(
            GestureSplit(axes: [.leftRight: .space], arms: [.up: overview])
        )
        let data = try JSONEncoder().encode(action)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"left_right\":{\"family\":\"space\"}"))
        #expect(
            try JSONDecoder().decode(GestureAction.self, from: data)
                == action
        )
    }

    @Test("a body the fold would change, or a mixed-up body, is refused")
    func decodeRefuses() {
        // An arm under an axis family.
        #expect(throws: DecodingError.self) {
            try decode(
                #"{"split":{"left_right":{"family":"space"},"#
                    + #""left":{"lua":"a()"}}}"#
            )
        }
        // Both axes on one family: the whole family's spelling.
        #expect(throws: DecodingError.self) {
            try decode(
                #"{"split":{"left_right":{"family":"focus"},"#
                    + #""up_down":{"family":"focus"}}}"#
            )
        }
        // Lua under an axis, a family under a direction.
        #expect(throws: DecodingError.self) {
            try decode(#"{"split":{"up_down":{"lua":"a()"}}}"#)
        }
        #expect(throws: DecodingError.self) {
            try decode(#"{"split":{"up":{"family":"space"}}}"#)
        }
        // An axis body carrying anything beside its family.
        #expect(throws: DecodingError.self) {
            try decode(
                #"{"split":{"left_right":{"family":"space","lua":"a()"}}}"#
            )
        }
    }

    @Test("only a swipe takes an axis family")
    func axisNeedsASwipe() {
        let action = GestureAction.split(
            GestureSplit(axes: [.upDown: .walk], arms: [:])
        )
        #expect(
            action.refusal(on: GestureKey(.wheel, hyper)) == .axisNotOffered
        )
        #expect(action.refusal(on: GestureKey(.swipe3, hyper)) == nil)
    }

    @Test("the verb's table takes a family per axis and Lua per way")
    @MainActor
    func verbTable() {
        let mixed = KiwiCore.gestureAction(
            .object([
                "left_right": .string("space"),
                "up": .string("x()"),
            ])
        )
        #expect(
            mixed
                == .split(
                    GestureSplit(
                        axes: [.leftRight: .space],
                        arms: [.up: LuaAction(lua: "x()")]
                    )
                )
        )
        // Lua under an axis refuses the whole table, never drops the
        // axis and keeps the rest.
        #expect(
            KiwiCore.gestureAction(
                .object([
                    "left_right": .string("x()"),
                    "up": .string("y()"),
                ])
            ) == nil
        )
    }

    /// Rotate is a direction pair (#1873 ▸ owner ruling
    /// 2026-11-15): whole, the layout family; split, one action per
    /// way through the same arms a swipe takes, and no axis.
    @Test("rotate binds the layout family or one action per way")
    func rotatePair() {
        let key = GestureKey(.rotate, hyper)
        #expect(GestureAction.family(.layout).refusal(on: key) == nil)
        #expect(
            GestureAction.split([.clockwise: overview]).refusal(on: key)
                == nil
        )
        #expect(
            GestureAction.run(overview).refusal(on: key)
                == .directionalNeedsFamily
        )
        #expect(
            GestureAction.split(
                GestureSplit(axes: [.leftRight: .layout], arms: [:])
            ).refusal(on: key) == .axisNotOffered
        )
        #expect(
            GestureAction.family(.layout).refusal(
                on: GestureKey(.swipe3, hyper)
            ) == .familyNotOffered
        )
        #expect(
            GestureFamily.layout.lua(.clockwise) == "KiwiDesk.cycle_mode()"
        )
        #expect(
            GestureFamily.layout.lua(.counterClockwise)
                == "KiwiDesk.cycle_mode(\"prev\")"
        )
    }
}
