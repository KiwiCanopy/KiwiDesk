import AppKit
import Testing

@testable import KiwiDesk

// The snap-in recorder (#212), driven through the testable
// seam (`handle(_:keyCode:flags:)`) — no NSEvents needed. Key
// codes: 38 = J, 40 = K, 53 = Escape (ANSI layout).

@MainActor
private final class Capture {
    var outcomes: [ChordRecorder.Outcome] = []
    var previews: [String] = []

    func attach(_ recorder: ChordRecorder) {
        recorder.start(
            preview: { [weak self] display in
                self?.previews.append(display)
            },
            finish: { [weak self] in
                self?.outcomes.append($0)
            }
        )
    }

    var lockedCombo: String? {
        guard case .chord(let combo) = outcomes.first else {
            return nil
        }
        return combo
    }
}

@Suite("Chord recorder snap-in (#212)")
@MainActor
struct ChordRecorderTests {
    @Test("The first key-down locks modifiers + key")
    func keyDownLocks() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = Capture()
        capture.attach(recorder)
        recorder.handle(
            .flagsChanged,
            keyCode: 55,
            flags: [.command]
        )
        recorder.handle(
            .keyDown,
            keyCode: 38,
            flags: [.command]
        )
        #expect(capture.lockedCombo == "command+j")
        #expect(capture.outcomes.count == 1)
        #expect(
            recorder.handle(
                .keyUp,
                keyCode: 38,
                flags: [.command]
            )
        )
    }

    @Test("Released modifiers don't linger — bare key locks")
    func releasedModifiersDropOut() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = Capture()
        capture.attach(recorder)
        recorder.handle(
            .flagsChanged,
            keyCode: 55,
            flags: [.command]
        )
        recorder.handle(.flagsChanged, keyCode: 55, flags: [])
        recorder.handle(.keyDown, keyCode: 38, flags: [])
        #expect(capture.lockedCombo == "j")
        #expect(
            recorder.handle(.keyUp, keyCode: 38, flags: [])
        )
    }

    @Test("The modifier preview mirrors what is held")
    func modifierPreview() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = Capture()
        capture.attach(recorder)
        recorder.handle(
            .flagsChanged,
            keyCode: 59,
            flags: [.control]
        )
        recorder.handle(
            .flagsChanged,
            keyCode: 58,
            flags: [.control, .option]
        )
        recorder.handle(.flagsChanged, keyCode: 59, flags: [])
        #expect(capture.previews == ["⌃", "⌃⌥", ""])
        #expect(capture.outcomes.isEmpty)
    }

    @Test("Bare Escape cancels")
    func bareEscapeCancels() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = Capture()
        capture.attach(recorder)
        recorder.handle(.keyDown, keyCode: 53, flags: [])
        guard case .cancelled = capture.outcomes.first else {
            Issue.record("expected .cancelled")
            return
        }
        #expect(
            recorder.handle(.keyUp, keyCode: 53, flags: [])
        )
    }

    @Test("Escape WITH modifiers records — ⌃Escape is valid")
    func modifiedEscapeRecords() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = Capture()
        capture.attach(recorder)
        recorder.handle(
            .keyDown,
            keyCode: 53,
            flags: [.control]
        )
        #expect(capture.lockedCombo == "control+escape")
        #expect(
            recorder.handle(
                .keyUp,
                keyCode: 53,
                flags: [.control]
            )
        )
    }

    @Test("An unrepresentable key is swallowed; recording continues")
    func unrepresentableKeyContinues() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = Capture()
        capture.attach(recorder)
        // 255 maps to no KeyCombo name.
        let swallowed = recorder.handle(
            .keyDown,
            keyCode: 255,
            flags: [.command]
        )
        #expect(swallowed)
        #expect(capture.outcomes.isEmpty)
        #expect(
            recorder.handle(
                .keyUp,
                keyCode: 255,
                flags: [.command]
            )
        )
        recorder.handle(
            .keyDown,
            keyCode: 40,
            flags: [.command]
        )
        #expect(capture.lockedCombo == "command+k")
        #expect(
            recorder.handle(
                .keyUp,
                keyCode: 40,
                flags: [.command]
            )
        )
    }

    @Test("keyUp events pass through untouched")
    func keyUpPassesThrough() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = Capture()
        capture.attach(recorder)
        // A key held from before the recording started
        // releases — its keyUp belongs to the original
        // responder.
        let swallowed = recorder.handle(
            .keyUp,
            keyCode: 38,
            flags: []
        )
        #expect(!swallowed)
        #expect(capture.outcomes.isEmpty)
    }

    @Test("A swallowed keyDown also swallows its keyUp")
    func pairedKeyUpIsSwallowed() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = Capture()
        capture.attach(recorder)

        #expect(
            recorder.handle(
                .keyDown,
                keyCode: 38,
                flags: [.command]
            )
        )
        #expect(
            recorder.handle(
                .keyUp,
                keyCode: 38,
                flags: [.command]
            )
        )
        #expect(
            !recorder.handle(
                .keyUp,
                keyCode: 38,
                flags: [.command]
            )
        )
        #expect(capture.lockedCombo == "command+j")
    }

    @Test("Key-up ownership survives stop and restart")
    func keyUpSurvivesRestart() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let first = Capture()
        first.attach(recorder)
        recorder.handle(
            .keyDown,
            keyCode: 38,
            flags: [.command]
        )

        recorder.stop()
        let second = Capture()
        second.attach(recorder)

        #expect(
            recorder.handle(
                .keyUp,
                keyCode: 38,
                flags: [.command]
            )
        )
        #expect(first.lockedCombo == "command+j")
        #expect(second.outcomes.isEmpty)
    }

    @Test("finish fires exactly once")
    func finishFiresOnce() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = Capture()
        capture.attach(recorder)
        recorder.handle(
            .keyDown,
            keyCode: 38,
            flags: [.command]
        )
        // The monitors are torn down after the lock; a stray
        // second event must not re-fire.
        recorder.handle(
            .keyDown,
            keyCode: 40,
            flags: [.command]
        )
        #expect(capture.outcomes.count == 1)
        #expect(
            recorder.handle(
                .keyUp,
                keyCode: 38,
                flags: [.command]
            )
        )
        #expect(
            recorder.handle(
                .keyUp,
                keyCode: 40,
                flags: [.command]
            )
        )
    }
}
