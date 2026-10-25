import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The recorder keeps the side a modifier was pressed on while the
/// switch is on (#2601 ▸ Ruling): read from the event's device bits,
/// plain where both sides are down or the Hyper key owns the
/// modifier, and unsided under a held Hyper. Key code 4 = H.
@Suite("Recorder keeps a modifier's side (#2601)")
@MainActor
struct ModifierSideRecorderTests {
    /// ⌘ with its right device bit, ⌘ with both, ⌥ with its left.
    private let rightCommand = NSEvent.ModifierFlags(
        rawValue: NSEvent.ModifierFlags.command.rawValue | 0x10
    )
    private let bothCommands = NSEvent.ModifierFlags(
        rawValue: NSEvent.ModifierFlags.command.rawValue | 0x18
    )
    private let leftCommand = NSEvent.ModifierFlags(
        rawValue: NSEvent.ModifierFlags.command.rawValue | 0x08
    )

    @Test("a side is kept only while sides are handed in")
    func sideFollowsTheSwitch() {
        let on = ChordRecorder.combo(
            keyCode: 4,
            flags: rightCommand,
            hyper: false,
            sides: RecorderSides()
        )
        #expect(on == "rcmd+h")
        let off = ChordRecorder.combo(
            keyCode: 4,
            flags: rightCommand,
            hyper: false,
            sides: nil
        )
        #expect(off == "command+h")
    }

    @Test("both sides down records plain")
    func bothSidesArePlain() {
        let combo = ChordRecorder.combo(
            keyCode: 4,
            flags: bothCommands,
            hyper: false,
            sides: RecorderSides()
        )
        #expect(combo == "command+h")
    }

    @Test("the Hyper key's modifier records plain on its other side")
    func oneSidedHyperFreesTheOther() {
        let sides = RecorderSides(hyperKey: .rightCommand)
        #expect(sides.modifiers(leftCommand) == .command)
        let option = NSEvent.ModifierFlags(
            rawValue: NSEvent.ModifierFlags.option.rawValue | 0x20
        )
        #expect(
            sides.modifiers(option)
                == HotkeyModifiers.option.union(.side(.left, of: .option))
        )
    }

    @Test("a held Hyper records unsided")
    func hyperIsUnsided() {
        let combo = ChordRecorder.combo(
            keyCode: 4,
            flags: rightCommand,
            hyper: true,
            sides: RecorderSides()
        )
        #expect(combo == "hyper+command+h")
        #expect(KeyCombo.parse(combo ?? "") != nil)
    }

    @Test("the preview draws the side a press would keep")
    func previewShowsTheSide() {
        #expect(
            ChordRecorder.preview(
                rightCommand,
                hyper: false,
                sides: RecorderSides()
            ) == "R⌘"
        )
        #expect(
            ChordRecorder.preview(rightCommand, hyper: false, sides: nil)
                == "⌘"
        )
    }

    @Test("the live recorder records through the sides it was handed")
    func recorderRoutesTheSides() {
        let recorder = ChordRecorder()
        defer { recorder.stop() }
        var locked: String?
        recorder.start(
            sides: RecorderSides(),
            preview: { _ in },
            finish: {
                if case .chord(let combo) = $0 { locked = combo }
            }
        )
        recorder.handle(.keyDown, keyCode: 4, flags: rightCommand)
        #expect(locked == "rcmd+h")
    }

    @Test("both recorder mounts hand the sides down to the field")
    func mountsWireTheSides() throws {
        let settings = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        func read(_ path: String) throws -> String {
            SourceScan.stripComments(
                try String(
                    contentsOf: settings.appendingPathComponent(path),
                    encoding: .utf8
                )
            )
        }
        let needle = ".environment(\\.recorderSides, model.recorderSides)"
        #expect(
            try read("Sections/ShortcutsSection.swift").contains(needle)
        )
        #expect(
            try read("Components/KiwiVision/KiwiVisionLensPage.swift")
                .contains(needle)
        )
        let field = try read(
            "Components/Keybindings/Recorder/KeyRecorderField.swift"
        )
        #expect(field.contains("sides: recorderSides,"))
    }
}
