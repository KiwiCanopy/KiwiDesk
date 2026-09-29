import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

// The scroll gestures' modifier-only recording (#1656 ruling):
// letters are ignored, and the largest set held at once commits
// when every key is released. Key codes: 38 = J, 53 = Escape.

@Suite("Chord recorder, modifiers only (#1656)")
@MainActor
struct ChordRecorderModifierTests {
    private final class Capture {
        var outcomes: [ChordRecorder.Outcome] = []
        var previews: [String] = []

        var chord: ScrollChord? {
            guard case .modifiers(let chord) = outcomes.first else {
                return nil
            }
            return chord
        }
    }

    private func start(_ recorder: ChordRecorder) -> Capture {
        let capture = Capture()
        recorder.start(
            mode: .modifiers,
            preview: { capture.previews.append($0) },
            finish: { capture.outcomes.append($0) }
        )
        return capture
    }

    @Test("the largest set held commits on the last release")
    func largestSetCommits() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = start(recorder)
        recorder.handle(.flagsChanged, keyCode: 59, flags: [.control])
        recorder.handle(
            .flagsChanged,
            keyCode: 58,
            flags: [.control, .option]
        )
        recorder.handle(.flagsChanged, keyCode: 59, flags: [.option])
        #expect(capture.outcomes.isEmpty)
        recorder.handle(.flagsChanged, keyCode: 58, flags: [])
        #expect(capture.chord == [.control, .option])
        #expect(capture.outcomes.count == 1)
        #expect(capture.previews.contains("⌃⌥"))
    }

    @Test("a letter is swallowed and ignored")
    func lettersAreIgnored() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = start(recorder)
        recorder.handle(
            .flagsChanged,
            keyCode: 55,
            flags: [.command, .shift]
        )
        #expect(
            recorder.handle(
                .keyDown,
                keyCode: 38,
                flags: [.command, .shift]
            )
        )
        #expect(capture.outcomes.isEmpty)
        recorder.handle(.flagsChanged, keyCode: 55, flags: [])
        #expect(capture.chord == [.command, .shift])
    }

    @Test("bare Escape cancels")
    func escapeCancels() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = start(recorder)
        recorder.handle(.keyDown, keyCode: 53, flags: [])
        guard case .cancelled = capture.outcomes.first else {
            Issue.record("expected a cancel, got \(capture.outcomes)")
            return
        }
    }

    @Test("a combo recorder never locks on modifiers alone")
    func comboModeIsUnchanged() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = Capture()
        recorder.start(
            preview: { capture.previews.append($0) },
            finish: { capture.outcomes.append($0) }
        )
        recorder.handle(.flagsChanged, keyCode: 59, flags: [.control])
        recorder.handle(.flagsChanged, keyCode: 59, flags: [])
        #expect(capture.outcomes.isEmpty)
    }
}
