import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A gesture row's keys take Hyper (#3407): with a Hyper key set,
/// the modifiers-only recorder reads F18 as `hyper` while it is
/// held; with none set, F18 records nothing. Key code 59 = ⌃.
@Suite("Chord recorder, modifiers with Hyper (#3407)")
@MainActor
struct ChordRecorderHyperModifierTests {
    private let f18 = ChordRecorder.hyperCode

    private func start(
        _ recorder: ChordRecorder,
        hyper: Bool
    ) -> () -> ScrollChord? {
        var outcome: ChordRecorder.Outcome?
        recorder.start(
            mode: .modifiers,
            hyper: hyper,
            preview: { _ in },
            finish: { outcome = $0 }
        )
        return {
            guard case .modifiers(let chord)? = outcome else { return nil }
            return chord
        }
    }

    @Test("Hyper alone commits on its release")
    func hyperAlone() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let chord = start(recorder, hyper: true)
        recorder.handle(.keyDown, keyCode: f18, flags: [])
        #expect(chord() == nil)
        recorder.handle(.keyUp, keyCode: f18, flags: [])
        #expect(chord() == .hyper)
    }

    @Test("Hyper with a modifier commits the largest set")
    func hyperWithControl() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let chord = start(recorder, hyper: true)
        recorder.handle(.keyDown, keyCode: f18, flags: [])
        recorder.handle(.flagsChanged, keyCode: 59, flags: [.control])
        recorder.handle(.keyUp, keyCode: f18, flags: [.control])
        #expect(chord() == nil)
        recorder.handle(.flagsChanged, keyCode: 59, flags: [])
        #expect(chord() == [.hyper, .control])
    }

    @Test("with no Hyper key, F18 records nothing")
    func hyperOff() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let chord = start(recorder, hyper: false)
        recorder.handle(.keyDown, keyCode: f18, flags: [])
        recorder.handle(.keyUp, keyCode: f18, flags: [])
        recorder.handle(.flagsChanged, keyCode: 59, flags: [.control])
        recorder.handle(.flagsChanged, keyCode: 59, flags: [])
        #expect(chord() == [.control])
    }

    @Test("the gesture well starts the recorder with Hyper's switch")
    func wellPassesTheSwitch() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Gestures/"
                    + "GestureChordRecorder.swift"
            )
        let source = try String(contentsOf: file, encoding: .utf8)
        #expect(source.contains("hyper: !hyperKeyIsOff,"))
        #expect(source.contains(".opacity(hyperDormant ? 0.55 : 1)"))
    }
}
