import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Hyper key's Settings row (#1870): the recorder's one-key
/// mode, the words the row draws and where it is offered.
@Suite("Hyper key row")
@MainActor
struct HyperKeyRowTests {
    private final class Capture {
        var outcomes: [ChordRecorder.Outcome] = []
        var code: UInt16? {
            guard case .sourceKey(let code) = outcomes.first else {
                return nil
            }
            return code
        }
    }

    private func start(_ recorder: ChordRecorder) -> Capture {
        let capture = Capture()
        recorder.start(
            mode: .sourceKey,
            preview: { _ in },
            finish: { capture.outcomes.append($0) }
        )
        return capture
    }

    @Test("a modifier commits on its press, by its sided code")
    func modifierPressCommits() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = start(recorder)
        // A release of a key held before recording is no press.
        recorder.handle(.flagsChanged, keyCode: 55, flags: [])
        #expect(capture.outcomes.isEmpty)
        recorder.handle(.flagsChanged, keyCode: 54, flags: [.command])
        #expect(capture.code == 54)  // Right ⌘, not Left (55)
    }

    @Test("a key down commits, Caps Lock commits, Escape cancels")
    func keysCommit() {
        let f13 = ChordRecorder()
        defer { f13.stop() }
        #expect(start(f13).code == nil)
        let capture = start(f13)
        f13.handle(.keyDown, keyCode: 105, flags: [])
        #expect(capture.code == 105)
        let caps = ChordRecorder()
        defer { caps.stop() }
        let capsCapture = start(caps)
        caps.handle(.flagsChanged, keyCode: 57, flags: [])
        #expect(capsCapture.code == 57)
        let escape = ChordRecorder()
        defer { escape.stop() }
        let escaped = start(escape)
        escape.handle(.keyDown, keyCode: 53, flags: [])
        guard case .cancelled = escaped.outcomes.first else {
            Issue.record("bare Escape must cancel")
            return
        }
    }

    @Test("the row names the key and its cost")
    func words() {
        LocalizationManager.shared.select("en")
        #expect(HyperKeyWords.name(.rightCommand) == "Right ⌘")
        #expect(HyperKeyWords.name(.leftOption) == "Left ⌥")
        #expect(HyperKeyWords.name(.f13) == "F13")
        #expect(HyperKeyWords.name(.capsLock) == "Caps Lock")
        let modifier = HyperKeyWords.caption(.rightCommand)
        #expect(modifier.hasPrefix("Right ⌘ is now Hyper"))
        #expect(modifier.contains("Left ⌘ still works as ⌘"))
        #expect(HyperKeyWords.caption(.f13).contains("no other job"))
        #expect(HyperKeyWords.caption(.f5).contains("its own action"))
        #expect(HyperKeyWords.caption(nil).contains("Caps Lock"))
        #expect(HyperKeyWords.trouble(.refused) != nil)
        #expect(HyperKeyWords.trouble(.on) == nil)
    }

    @Test("offered in Power User, and in Simple once a key is set")
    func offer() {
        #expect(HyperKeyRow.isOffered(in: .powerUser, key: nil))
        #expect(!HyperKeyRow.isOffered(in: .simple, key: nil))
        #expect(HyperKeyRow.isOffered(in: .simple, key: .capsLock))
    }

    @Test("the board can mark every modifier and Caps Lock")
    func boardCarriesSources() {
        for type in [KeyboardMatrix.PhysicalType.ansi, .iso] {
            let sources = KeyboardMatrix.rows(for: type)
                .flatMap { $0 }.compactMap(\.source)
            #expect(Set(sources).count == sources.count)
            #expect(sources.contains(.capsLock))
            #expect(sources.contains(.rightCommand))
            #expect(sources.contains(.leftShift))
            // Only legend caps carry a source: a bindable key's
            // code stays the board's.
            #expect(
                KeyboardMatrix.rows(for: type).flatMap { $0 }
                    .allSatisfy { $0.source == nil || $0.code == nil }
            )
        }
    }
}
