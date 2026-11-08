import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

// The recorder records a modifier tap through Core's one rule
// (#1872). Key codes: 54 = Right ⌘, 55 = Left ⌘, 4 = H. Device
// bits: Right ⌘ 0x10, Left ⌘ 0x08.

@MainActor
private final class TapCapture {
    var outcomes: [ChordRecorder.Outcome] = []
    var pending: [KeyCombo?] = []

    func attach(
        _ recorder: ChordRecorder,
        sides: RecorderSides? = nil,
        taps: Bool = true
    ) {
        recorder.start(
            sides: sides,
            taps: taps,
            pendingTap: { [weak self] in self?.pending.append($0) },
            preview: { _ in },
            finish: { [weak self] in self?.outcomes.append($0) }
        )
    }

    var locked: String? {
        guard case .chord(let combo) = outcomes.first else {
            return nil
        }
        return combo
    }
}

@Suite("Chord recorder records modifier taps (#1872)")
@MainActor
struct ChordRecorderTapTests {
    private let rightCommand = NSEvent.ModifierFlags(
        rawValue: NSEvent.ModifierFlags.command.rawValue | 0x10
    )

    private func tap(
        _ recorder: ChordRecorder,
        down: TimeInterval,
        up: TimeInterval
    ) {
        recorder.handle(
            .flagsChanged,
            keyCode: 54,
            flags: rightCommand,
            time: down
        )
        recorder.handle(.flagsChanged, keyCode: 54, flags: [], time: up)
    }

    @Test("a double tap commits at once, either-side with sides off")
    func doubleTapEitherSide() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = TapCapture()
        capture.attach(recorder)
        tap(recorder, down: 0, up: 0.1)
        #expect(capture.outcomes.isEmpty)
        tap(recorder, down: 0.2, up: 0.3)
        #expect(capture.locked == "cmd+cmd")
    }

    @Test("a double tap keeps its side while sides are told apart")
    func doubleTapSided() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = TapCapture()
        capture.attach(recorder, sides: RecorderSides())
        tap(recorder, down: 0, up: 0.1)
        tap(recorder, down: 0.2, up: 0.3)
        #expect(capture.locked == "rcmd+rcmd")
    }

    @Test("a single tap waits out the gap, then records its side")
    func singleTapCommitsLater() async throws {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = TapCapture()
        capture.attach(recorder)
        tap(recorder, down: 0, up: 0.1)
        #expect(capture.outcomes.isEmpty)
        #expect(capture.pending.last == KeyCombo.parse("rcmd"))
        let wait = try #require(recorder.tapWait)
        await wait.value
        #expect(capture.locked == "rcmd")
    }

    @Test("a held modifier records nothing; a key after a tap is a chord")
    func heldAndChord() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = TapCapture()
        capture.attach(recorder)
        tap(recorder, down: 0, up: 0.4)
        #expect(recorder.tapWait == nil)
        #expect(capture.outcomes.isEmpty)
        tap(recorder, down: 1, up: 1.1)
        #expect(recorder.tapWait != nil)
        recorder.handle(
            .flagsChanged,
            keyCode: 54,
            flags: rightCommand,
            time: 1.2
        )
        recorder.handle(.keyDown, keyCode: 4, flags: rightCommand, time: 1.3)
        #expect(capture.locked == "command+h")
    }

    @Test("with taps off, a quick tap records nothing")
    func tapsOff() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = TapCapture()
        capture.attach(recorder, taps: false)
        tap(recorder, down: 0, up: 0.1)
        tap(recorder, down: 0.2, up: 0.3)
        #expect(capture.outcomes.isEmpty)
        #expect(recorder.tapWait == nil)
    }
}
