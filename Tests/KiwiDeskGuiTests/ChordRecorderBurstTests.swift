import AppKit
import Foundation
import Testing

@testable import KiwiDesk

// The release-burst window of the chord recorder (#68): a
// release stashes the chord, a full release within the window
// locks it, the display freezes on it meanwhile, and a slow
// disassembly expires it. Key codes: 38 = J, 40 = K. The
// Capture helper is a per-file copy (suite convention).

@MainActor
private final class Capture {
    var outcomes: [ChordRecorder.Outcome] = []
    var previews: [String] = []
    var hints: [String?] = []

    func attach(_ recorder: ChordRecorder) {
        recorder.start(
            preview: { [weak self] display, _ in
                self?.previews.append(display)
            },
            hint: { [weak self] in
                self?.hints.append($0)
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

@Suite("Chord recorder release burst")
@MainActor
struct ChordRecorderBurstTests {
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

    @Test("preview waits out the release burst, then settles")
    func previewSettlesLazily() {
        let recorder = ChordRecorder()
        let capture = Capture()
        capture.attach(recorder)
        var clock = Date(timeIntervalSince1970: 1000)
        recorder.now = { clock }
        recorder.handle(
            .keyDown,
            keyCode: 38,
            flags: [.command]
        )
        let shown = capture.previews.last
        // J released while ⌘ is still down: the preview keeps
        // the chord — an instant downgrade flashed the combo
        // away right before every normal lock-in.
        recorder.handle(
            .keyUp,
            keyCode: 38,
            flags: [.command]
        )
        #expect(capture.previews.last == shown)
        #expect(capture.outcomes.isEmpty)
        // Only a genuinely lingering hold settles the preview
        // down to what is actually held.
        let stamp = clock
        clock += 1
        recorder.settleBurst(stampedAt: stamp)
        #expect(capture.previews.last == "⌘")
    }

    @Test("a slow disassembly never locks the stale chord")
    func expiredCandidateKeepsRecording() {
        let recorder = ChordRecorder()
        let capture = Capture()
        capture.attach(recorder)
        var clock = Date(timeIntervalSince1970: 1000)
        recorder.now = { clock }
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
        // The user ponders past the release burst window…
        clock += 1
        recorder.handle(.flagsChanged, keyCode: 55, flags: [])
        // …so nothing locks (the preview already dropped the
        // J long ago) and the recorder stays live:
        #expect(capture.outcomes.isEmpty)
        #expect(capture.previews.last == "")
        recorder.handle(.keyDown, keyCode: 40, flags: [])
        recorder.handle(.keyUp, keyCode: 40, flags: [])
        #expect(capture.lockedCombo == "k")
    }
}
