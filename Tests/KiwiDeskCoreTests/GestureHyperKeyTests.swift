import Foundation
import Testing

@testable import KiwiDeskCore

/// Hyper as a gesture key (#3407 ▸ Ruling): it stands for the two
/// modifiers a scroll needs and for the one any other input needs,
/// alone or with others; a wheel still refuses shift.
@Suite("Gesture keys take Hyper")
struct GestureHyperKeyTests {
    @Test("the refusal truth table")
    func truthTable() {
        let rows: [(GestureInput, ScrollChord, GestureRefusal?)] = [
            // The two-or-more inputs.
            (.wheel, .hyper, nil),
            (.wheel, [.hyper, .control], nil),
            (.wheel, [.hyper, .shift], .shiftOnWheel),
            (.wheel, [.control], .singleModifierScroll),
            (.wheel, [.control, .option], nil),
            (.wheel, [], .needsModifier),
            (.wheelX, .hyper, nil),
            (.wheelX, [.hyper, .shift], .shiftOnWheel),
            (.wheelX, [.option], .singleModifierScroll),
            (.swipe2, .hyper, nil),
            (.swipe2, [.hyper, .shift], nil),
            (.swipe2, [.command], .singleModifierScroll),
            (.swipe2, [.control, .option], nil),
            // The one-or-more inputs.
            (.click, .hyper, nil),
            (.click, [], .needsModifier),
            (.drag, .hyper, nil),
            (.swipe3, .hyper, nil),
            (.spread, [.hyper, .command], nil),
            // A keyless input takes Hyper too.
            (.tap4, .hyper, nil),
        ]
        for (input, chord, refusal) in rows {
            #expect(
                GestureKey(input, chord).refusal == refusal,
                "\(input) \(chord.spelling)"
            )
        }
    }

    @Test("hyper is spelled first and read back")
    func spelling() throws {
        let chord: ScrollChord = [.hyper, .control, .option]
        #expect(chord.spelling == "hyper+control+option")
        #expect(ScrollChord(spelling: "hyper") == .hyper)
        #expect(ScrollChord(spelling: "cmd+hyper") == [.command, .hyper])
        #expect(ScrollChord(spelling: "hyper+hyper") == nil)
        let key = try #require(GestureKey(spelling: "wheel:hyper"))
        #expect(key == GestureKey(.wheel, .hyper))
        // One spelling per key: the canonical order alone reads.
        #expect(GestureKey(spelling: "wheel:control+hyper") == nil)
    }

    @Test("every member survives the stored spelling")
    func roundTrip() throws {
        let members: [ScrollChord] = [
            .control, .option, .shift, .command, .hyper,
        ]
        let all = members.reduce(ScrollChord()) { $0.union($1) }
        for bits in 0...all.rawValue {
            let chord = ScrollChord(rawValue: bits)
            #expect(ScrollChord(spelling: chord.spelling) == chord)
            let data = try JSONEncoder().encode(chord)
            #expect(
                try JSONDecoder().decode(ScrollChord.self, from: data)
                    == chord
            )
        }
    }

    @Test("a hyper binding is taken while no Hyper key is set")
    @MainActor
    func bindsWithoutAHyperKey() {
        let core = makeTestCore()
        #expect(core.keys.hyperEnabled == false)
        let response = core.execute(
            "gesture.bind",
            args: [.string("wheel"), .string("hyper"), .string("walk")]
        )
        #expect(response.isSuccess)
        let key = GestureKey(.wheel, .hyper)
        #expect(core.mouse.gestures.resolved[key] == .family(.walk))
        let refused = core.execute(
            "gesture.bind",
            args: [
                .string("wheel"), .string("hyper+shift"), .string("walk"),
            ]
        )
        #expect(!refused.isSuccess)
    }
}
