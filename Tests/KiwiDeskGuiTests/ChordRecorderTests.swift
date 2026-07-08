import AppKit
import Testing

@testable import KiwiDesk

// The lock-on-full-release chord state machine (#68 recorder
// UX), driven through the testable seam
// (`handle(_:keyCode:flags:)`) — no NSEvents needed. Key
// codes: 38 = J, 40 = K, 53 = Escape (ANSI layout).

@MainActor
private final class Capture {
    var outcomes: [ChordRecorder.Outcome] = []
    var previews: [String] = []

    func attach(_ recorder: ChordRecorder) {
        recorder.start(
            preview: { [weak self] in
                self?.previews.append($0)
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

@Suite("Chord recorder lock-on-release")
@MainActor
struct ChordRecorderTests {
    @Test("staggered release keeps the chord — ⌘ up first")
    func commandReleasedFirst() {
        let recorder = ChordRecorder()
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
        // ⌘ released a split second before J.
        recorder.handle(.flagsChanged, keyCode: 55, flags: [])
        #expect(capture.outcomes.isEmpty)
        recorder.handle(.keyUp, keyCode: 38, flags: [])
        #expect(capture.lockedCombo == "command+j")
        #expect(capture.outcomes.count == 1)
    }

    @Test("staggered release keeps the chord — base up first")
    func baseReleasedFirst() {
        let recorder = ChordRecorder()
        let capture = Capture()
        capture.attach(recorder)
        recorder.handle(
            .keyDown,
            keyCode: 38,
            flags: [.command]
        )
        // J released while ⌘ is still down — no lock yet.
        recorder.handle(
            .keyUp,
            keyCode: 38,
            flags: [.command]
        )
        #expect(capture.outcomes.isEmpty)
        recorder.handle(.flagsChanged, keyCode: 55, flags: [])
        #expect(capture.lockedCombo == "command+j")
    }

    @Test("mid-chord correction re-snapshots — ⌘J then ⌘K")
    func midChordCorrection() {
        let recorder = ChordRecorder()
        let capture = Capture()
        capture.attach(recorder)
        recorder.handle(
            .keyDown,
            keyCode: 38,
            flags: [.command]
        )
        recorder.handle(
            .keyUp,
            keyCode: 38,
            flags: [.command]
        )
        recorder.handle(
            .keyDown,
            keyCode: 40,
            flags: [.command]
        )
        recorder.handle(
            .keyUp,
            keyCode: 40,
            flags: [.command]
        )
        recorder.handle(.flagsChanged, keyCode: 55, flags: [])
        #expect(capture.lockedCombo == "command+k")
    }

    @Test("modifiers accumulate while the base key is held")
    func modifierAccumulation() {
        let recorder = ChordRecorder()
        let capture = Capture()
        capture.attach(recorder)
        // J pressed a hair before ⌘ joins.
        recorder.handle(.keyDown, keyCode: 38, flags: [])
        recorder.handle(
            .flagsChanged,
            keyCode: 55,
            flags: [.command]
        )
        // ⌘ dropped again before J releases — the chord
        // never downgrades.
        recorder.handle(.flagsChanged, keyCode: 55, flags: [])
        recorder.handle(.keyUp, keyCode: 38, flags: [])
        #expect(capture.lockedCombo == "command+j")
    }

    @Test("two base keys held at once: last one wins")
    func multiBaseKeysNotCombined() {
        // A combo is modifiers + ONE key (Carbon
        // RegisterEventHotKey can't express ⌘J+K), so holding
        // a second base key re-snapshots instead of chording.
        let recorder = ChordRecorder()
        let capture = Capture()
        capture.attach(recorder)
        recorder.handle(
            .keyDown,
            keyCode: 38,
            flags: [.command]
        )
        recorder.handle(
            .keyDown,
            keyCode: 40,
            flags: [.command]
        )
        // Nothing locks while either key is down.
        recorder.handle(
            .keyUp,
            keyCode: 38,
            flags: [.command]
        )
        recorder.handle(
            .keyUp,
            keyCode: 40,
            flags: [.command]
        )
        #expect(capture.outcomes.isEmpty)
        recorder.handle(.flagsChanged, keyCode: 55, flags: [])
        #expect(capture.lockedCombo == "command+k")
    }

    @Test("bare key locks without modifiers")
    func bareKey() {
        let recorder = ChordRecorder()
        let capture = Capture()
        capture.attach(recorder)
        recorder.handle(.keyDown, keyCode: 38, flags: [])
        recorder.handle(.keyUp, keyCode: 38, flags: [])
        #expect(capture.lockedCombo == "j")
    }

    @Test("bare Escape cancels")
    func escapeCancels() {
        let recorder = ChordRecorder()
        let capture = Capture()
        capture.attach(recorder)
        recorder.handle(.keyDown, keyCode: 53, flags: [])
        guard case .cancelled = capture.outcomes.first else {
            Issue.record("expected .cancelled")
            return
        }
        #expect(capture.outcomes.count == 1)
    }

    @Test("a key held from before recording passes through")
    func untrackedKeyUpPassesThrough() {
        let recorder = ChordRecorder()
        let capture = Capture()
        capture.attach(recorder)
        // keyUp for a key whose keyDown predates recording:
        // not swallowed, and no lock (nothing pending).
        let swallowed = recorder.handle(
            .keyUp,
            keyCode: 40,
            flags: []
        )
        #expect(!swallowed)
        #expect(capture.outcomes.isEmpty)
        // A tracked key's keyUp IS swallowed.
        recorder.handle(.keyDown, keyCode: 38, flags: [])
        #expect(
            recorder.handle(.keyUp, keyCode: 38, flags: [])
        )
    }

    @Test("finish fires exactly once; stop() is silent")
    func finishFiresOnce() {
        let recorder = ChordRecorder()
        let capture = Capture()
        capture.attach(recorder)
        recorder.handle(.keyDown, keyCode: 38, flags: [])
        recorder.handle(.keyUp, keyCode: 38, flags: [])
        #expect(capture.outcomes.count == 1)
        // Post-finish events reach a reset machine: no
        // second outcome without a new start().
        recorder.handle(.keyDown, keyCode: 40, flags: [])
        recorder.handle(.keyUp, keyCode: 40, flags: [])
        #expect(capture.outcomes.count == 1)
    }
}
