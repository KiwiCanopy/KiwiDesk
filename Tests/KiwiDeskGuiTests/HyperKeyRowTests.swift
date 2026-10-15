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
        let rightDown = NSEvent.ModifierFlags(
            rawValue: NSEvent.ModifierFlags.command.rawValue | 0x10
        )
        recorder.handle(.flagsChanged, keyCode: 54, flags: rightDown)
        #expect(capture.code == 54)  // Right ⌘, not Left (55)
    }

    @Test("a release on one side while the other is held is no press")
    func otherSideHeldIsNoPress() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        let capture = start(recorder)
        // Left ⌘ (55) lets go; Right ⌘ still holds `.command`,
        // and only its own device bit (0x10) is down.
        let rightOnly = NSEvent.ModifierFlags(
            rawValue: NSEvent.ModifierFlags.command.rawValue | 0x10
        )
        recorder.handle(.flagsChanged, keyCode: 55, flags: rightOnly)
        #expect(capture.outcomes.isEmpty)
        let leftDown = NSEvent.ModifierFlags(
            rawValue: NSEvent.ModifierFlags.command.rawValue | 0x08
        )
        recorder.handle(.flagsChanged, keyCode: 55, flags: leftDown)
        #expect(capture.code == 55)
    }

    @Test("a key down commits, Caps Lock commits, Escape cancels")
    func keysCommit() {
        let f13 = ChordRecorder()
        defer { f13.stop() }
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
        #expect(HyperKeyWords.name(.rightShift) == "Right ⇧")
        #expect(HyperKeyWords.paused.contains("manages"))
        #expect(HyperKeyWords.trouble(.refused) != nil)
        #expect(HyperKeyWords.trouble(.on) == nil)
    }

    @Test("offered in Power User, and in Simple once a key is set")
    func offer() {
        #expect(HyperKeyRow.isOffered(in: .powerUser, key: nil))
        #expect(!HyperKeyRow.isOffered(in: .simple, key: nil))
        #expect(HyperKeyRow.isOffered(in: .simple, key: .capsLock))
    }

    @Test("the cap and the spoken board read one predicate")
    func boardMarksTheHyperKey() {
        let rows = KeyboardMatrix.rows(for: .ansi).flatMap { $0 }
        let caps = rows.first { $0.source == .capsLock }!
        #expect(KeyboardMatrix.legend(of: caps, hyper: .capsLock) == "✦")
        #expect(KeyboardMatrix.legend(of: caps, hyper: nil) == "⇪")
        #expect(
            KeyboardMatrix.legend(of: caps, hyper: .rightCommand) == "⇪"
        )
        #expect(KeyboardMatrix.draws(.rightCommand, on: .ansi))
        #expect(!KeyboardMatrix.draws(.f13, on: .ansi))
        #expect(!KeyboardMatrix.draws(nil, on: .ansi))
    }

    @Test("the board can mark every modifier and Caps Lock")
    func boardCarriesSources() {
        for type in [KeyboardMatrix.PhysicalType.ansi, .iso] {
            let sources = KeyboardMatrix.rows(for: type)
                .flatMap { $0 }.compactMap(\.source)
            #expect(Set(sources).count == sources.count)
            // Every key the board draws a cap for: Caps Lock and
            // the modifiers, less Right ⌃, which Mac boards lack.
            let drawable = Set(
                HyperSourceKey.allCases.filter {
                    switch $0.kind {
                    case .capsLock, .modifier: return true
                    case .systemKey, .spare: return false
                    }
                }
            ).subtracting([.rightControl])
            #expect(Set(sources) == drawable)
            // Only legend caps carry a source: a bindable key's
            // code stays the board's.
            #expect(
                KeyboardMatrix.rows(for: type).flatMap { $0 }
                    .allSatisfy { $0.source == nil || $0.code == nil }
            )
        }
    }

    /// The surfacing branches a source scan is the only net for
    /// (gui.md): the board takes the shared legend, and the row
    /// narrates a chosen key the core has not applied.
    @Test("the board and the row are wired to their predicates")
    func wiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings"
            )
        let board = SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "KeyboardBoard.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(board.contains("KeyboardMatrix.legend(of: key, hyper:"))
        let row = SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "HyperKeyRow.swift"
                ),
                encoding: .utf8
            )
        )
        // The view draws the one pure caption, handed the live
        // status (`captionStates` holds what it answers).
        #expect(row.contains("Self.captionText("))
        #expect(row.contains("status: model.hyperStatus"))
    }

    @Test("the caption names the state the key is in")
    func captionStates() {
        LocalizationManager.shared.select("en")
        let text = HyperKeyRow.captionText
        #expect(
            text(.capsLock, .refused, false)
                == HyperKeyWords.trouble(.refused)
        )
        #expect(
            text(.capsLock, .failed, false)
                == HyperKeyWords.trouble(.failed)
        )
        #expect(text(.capsLock, .off, false) == HyperKeyWords.paused)
        #expect(
            text(.capsLock, .on, false)
                == HyperKeyWords.caption(.capsLock)
        )
        #expect(text(nil, .off, false) == HyperKeyWords.caption(nil))
        #expect(text(.capsLock, .on, true) != HyperKeyWords.caption(.capsLock))
    }

    @Test("pressing the Hyper key again keeps the key it is")
    func f18KeepsTheKey() {
        let f18: UInt16 = 79
        #expect(
            HyperKeyField.committed(code: f18, current: .capsLock) == .capsLock
        )
        #expect(HyperKeyField.committed(code: f18, current: nil) == .f18)
        #expect(HyperKeyField.committed(code: 105, current: .capsLock) == .f13)
        #expect(HyperKeyField.committed(code: 4, current: nil) == nil)  // H
    }
}
