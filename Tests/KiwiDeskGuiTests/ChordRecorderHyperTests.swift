import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

// The Hyper key reaches the recorder as F18 (#1870): held, it is
// the `hyper` modifier of the chord the next key locks. Key
// codes: 48 = Tab, 53 = Escape, 38 = J.

@MainActor
private final class HyperCapture {
    var outcomes: [ChordRecorder.Outcome] = []
    var previews: [String] = []

    func attach(_ recorder: ChordRecorder, hyper: Bool) {
        recorder.start(
            hyper: hyper,
            preview: { [weak self] in self?.previews.append($0) },
            finish: { [weak self] in self?.outcomes.append($0) }
        )
    }

    var lockedCombo: String? {
        guard case .chord(let combo) = outcomes.first else {
            return nil
        }
        return combo
    }
}

@Suite("Chord recorder records the Hyper key (#1870)")
@MainActor
struct ChordRecorderHyperTests {
    private let f18 = HyperSourceKey.f18.keyCode

    @Test("Held F18 records as hyper, and alone commits nothing")
    func heldHyperLeadsTheChord() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = HyperCapture()
        capture.attach(recorder, hyper: true)
        #expect(recorder.handle(.keyDown, keyCode: f18, flags: []))
        #expect(capture.outcomes.isEmpty)
        #expect(capture.previews.last == ComboSymbols.hyperGlyph)
        recorder.handle(.keyDown, keyCode: 48, flags: [])
        #expect(capture.lockedCombo == "hyper+tab")
    }

    @Test("Hyper combines with the other modifiers")
    func hyperWithModifiers() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = HyperCapture()
        capture.attach(recorder, hyper: true)
        recorder.handle(.keyDown, keyCode: f18, flags: [])
        recorder.handle(.keyDown, keyCode: 38, flags: [.shift])
        #expect(capture.lockedCombo == "hyper+shift+j")
    }

    @Test("Hyper + Escape records instead of cancelling")
    func hyperEscapeRecords() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = HyperCapture()
        capture.attach(recorder, hyper: true)
        recorder.handle(.keyDown, keyCode: f18, flags: [])
        recorder.handle(.keyDown, keyCode: 53, flags: [])
        #expect(capture.lockedCombo == "hyper+escape")
    }

    @Test("A released Hyper key drops out of the chord")
    func releasedHyperDropsOut() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = HyperCapture()
        capture.attach(recorder, hyper: true)
        recorder.handle(.keyDown, keyCode: f18, flags: [])
        recorder.handle(.keyUp, keyCode: f18, flags: [])
        recorder.handle(.keyDown, keyCode: 48, flags: [])
        #expect(capture.lockedCombo == "tab")
    }

    @Test("With Hyper off, F18 is no modifier")
    func hyperOffIgnoresF18() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = HyperCapture()
        capture.attach(recorder, hyper: false)
        recorder.handle(.keyDown, keyCode: f18, flags: [])
        recorder.handle(.keyDown, keyCode: 48, flags: [])
        #expect(capture.lockedCombo == "tab")
    }
}
