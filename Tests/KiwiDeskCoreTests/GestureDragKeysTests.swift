import Foundation
import Testing

@testable import KiwiDeskCore

private let pan: ScrollChord = [.control, .option]

/// A drag holds its keys (#3199): a click or a hover_move on them is
/// dropped. Split from `GestureBindingTests` at the file ceiling.
@Suite("A drag's keys are the drag's")
struct GestureDragKeysTests {
    @Test("a drag's keys keep a click on them silent")
    func dragHoldsItsKeys() {
        let keys: ScrollChord = [.control, .option]
        let base = GestureMap([
            GestureKey(.click, keys): .bound(.run(LuaAction(lua: "x()"))),
            GestureKey(.click, [.shift, .command]): .bound(
                .run(LuaAction(lua: "y()"))
            ),
        ])
        let resolved = GestureSeeds.resolved(
            base: base,
            profile: nil,
            shortcutBase: .standard
        )
        #expect(resolved[GestureKey(.click, keys)] == nil)
        #expect(resolved[GestureKey(.click, [.shift, .command])] != nil)
    }

    @Test("a hover_move on a drag's keys is dropped, both ways")
    func hoverYieldsToADrag() {
        let resolved = GestureSeeds.resolved(
            base: GestureMap([
                GestureKey(.hoverMove, pan): .bound(.grab(.move))
            ]),
            profile: nil,
            shortcutBase: .standard
        )
        #expect(resolved[GestureKey(.hoverMove, pan)] == nil)
        let settings = ModifierDragSettings([
            ModifierDragBinding(.resize, chord: pan),
            ModifierDragBinding(.move, chord: pan, start: .hover),
        ]).sanitized
        #expect(
            settings.grabs == [ModifierDragBinding(.resize, chord: pan)]
        )
    }
}
