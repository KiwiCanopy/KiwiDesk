import Testing

@testable import KiwiDeskCore

/// The one tap rule (#1872, #1229 ▸ Detection), driven with
/// fabricated flag changes: real taps cannot be synthesised, so the
/// hand checks are the PR's eyeball list.
@Suite("Modifier tap detector (#1872)")
struct ModifierTapDetectorTests {
    private static let rightCommand = ModifierKey(.command, .right)
    private static let leftCommand = ModifierKey(.command, .left)

    /// The flags a press of `key` alone holds, as `held(by:)` reads
    /// them.
    private static func held(_ key: ModifierKey) -> HotkeyModifiers {
        key.kind.plain.union(.side(key.side, of: key.kind))
    }

    /// Presses `key` at `down` and lets go at `up`, returning both
    /// outputs.
    private static func tap(
        _ detector: inout ModifierTapDetector,
        _ key: ModifierKey,
        _ down: Double,
        _ up: Double
    ) -> ModifierTapDetector.Output {
        _ = detector.feed(.flags(held(key), at: down))
        return detector.feed(.flags([], at: up))
    }

    @Test("two quick presses of one key are a double tap at once")
    func doubleTap() throws {
        var detector = ModifierTapDetector()
        let first = Self.tap(&detector, Self.rightCommand, 0, 0.1)
        #expect(first.taps.isEmpty)
        #expect(first.pending?.key == Self.rightCommand)
        let second = Self.tap(&detector, Self.rightCommand, 0.3, 0.4)
        #expect(second.taps == [ModifierTap(Self.rightCommand, count: 2)])
        // Committed: the first tap's wait fires nothing.
        let token = try #require(first.pending?.token)
        #expect(detector.expire(token) == nil)
    }

    @Test("a single tap waits out the gap, then fires on its token")
    func singleTapWaits() throws {
        var detector = ModifierTapDetector()
        let out = Self.tap(&detector, Self.rightCommand, 0, 0.1)
        let token = try #require(out.pending?.token)
        #expect(detector.expire(token + 1) == nil)
        #expect(
            detector.expire(token) == ModifierTap(Self.rightCommand, count: 1)
        )
        #expect(detector.expire(token) == nil)
    }

    @Test("a key no double tap waits on fires at the release")
    func immediateSingle() {
        var detector = ModifierTapDetector(immediate: [Self.rightCommand])
        let out = Self.tap(&detector, Self.rightCommand, 0, 0.1)
        #expect(out.taps == [ModifierTap(Self.rightCommand, count: 1)])
        #expect(out.pending == nil)
    }

    @Test("a press held 250 ms or longer is no tap")
    func heldIsNoTap() {
        var detector = ModifierTapDetector(immediate: [Self.rightCommand])
        let out = Self.tap(&detector, Self.rightCommand, 0, 0.25)
        #expect(out.taps.isEmpty)
        #expect(out.pending == nil)
        // Nor does it count as the first of two.
        var two = ModifierTapDetector()
        _ = Self.tap(&two, Self.rightCommand, 0, 0.1)
        let late = Self.tap(&two, Self.rightCommand, 0.2, 0.5)
        #expect(late.taps.isEmpty)
    }

    @Test("a second press after 300 ms starts again")
    func gapRunsOut() {
        var detector = ModifierTapDetector()
        _ = Self.tap(&detector, Self.rightCommand, 0, 0.1)
        _ = detector.feed(.flags(Self.held(Self.rightCommand), at: 0.41))
        let out = detector.feed(.flags([], at: 0.5))
        #expect(out.taps.isEmpty)
        #expect(out.pending != nil)
    }

    @Test("a late timer's single tap fires at the next press")
    func lateTimer() {
        var detector = ModifierTapDetector()
        _ = Self.tap(&detector, Self.rightCommand, 0, 0.1)
        let press = detector.feed(
            .flags(Self.held(Self.rightCommand), at: 0.5)
        )
        #expect(press.taps == [ModifierTap(Self.rightCommand, count: 1)])
    }

    @Test("left then right is no double tap")
    func otherSideIsNoDouble() {
        var detector = ModifierTapDetector()
        let first = Self.tap(&detector, Self.leftCommand, 0, 0.1)
        let second = Self.tap(&detector, Self.rightCommand, 0.2, 0.3)
        #expect(second.taps.isEmpty)
        #expect(second.pending?.key == Self.rightCommand)
        let token = first.pending?.token ?? 0
        #expect(detector.expire(token) == nil)
    }

    @Test("a key, a click or a second modifier ends the count")
    func somethingBetween() {
        for between: ModifierTapDetector.Input in [.key, .mouseDown] {
            var detector = ModifierTapDetector()
            let first = Self.tap(&detector, Self.rightCommand, 0, 0.1)
            _ = detector.feed(between)
            let token = first.pending?.token ?? 0
            #expect(detector.expire(token) == nil)
            let again = Self.tap(&detector, Self.rightCommand, 0.2, 0.3)
            #expect(again.taps.isEmpty)
        }
        // ⌘ held, H pressed: a chord, no tap at the release.
        var chord = ModifierTapDetector(immediate: [Self.rightCommand])
        _ = chord.feed(.flags(Self.held(Self.rightCommand), at: 0))
        _ = chord.feed(.key)
        #expect(chord.feed(.flags([], at: 0.1)).taps.isEmpty)
        // ⌘ then ⇧ held together: no tap of either.
        var pair = ModifierTapDetector(immediate: [Self.rightCommand])
        let shift = ModifierKey(.shift, .left)
        _ = pair.feed(.flags(Self.held(Self.rightCommand), at: 0))
        _ = pair.feed(
            .flags(
                Self.held(Self.rightCommand).union(Self.held(shift)),
                at: 0.05
            )
        )
        _ = pair.feed(.flags(Self.held(Self.rightCommand), at: 0.08))
        #expect(pair.feed(.flags([], at: 0.1)).taps.isEmpty)
    }

    @Test("at most two taps: a third starts a new count")
    func noTriple() {
        var detector = ModifierTapDetector()
        _ = Self.tap(&detector, Self.rightCommand, 0, 0.05)
        _ = Self.tap(&detector, Self.rightCommand, 0.1, 0.15)
        let third = Self.tap(&detector, Self.rightCommand, 0.2, 0.25)
        #expect(third.taps.isEmpty)
        #expect(third.pending != nil)
    }

    @Test("the timings are #1229's")
    func timings() {
        #expect(ModifierTapDetector.pressLimit == 0.25)
        #expect(ModifierTapDetector.gapLimit == 0.3)
    }
}
