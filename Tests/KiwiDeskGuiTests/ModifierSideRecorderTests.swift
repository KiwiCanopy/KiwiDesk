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
        LocalizationManager.shared.select("en")
        #expect(
            ChordRecorder.preview(
                rightCommand,
                hyper: false,
                sides: RecorderSides()
            ) == "Right ⌘"
        )
        #expect(
            ChordRecorder.preview(rightCommand, hyper: false, sides: nil)
                == "⌘"
        )
        #expect(
            ChordRecorder.preview(
                rightCommand,
                hyper: true,
                sides: RecorderSides()
            ) == "✦⌘"
        )
    }

    @Test("a sided row hints it works either-side while sides are off")
    func eitherSideHint() {
        LocalizationManager.shared.select("en")
        func hint(_ combo: String, on: Bool) -> String? {
            KeyRecorderField.rowHint(
                combo: combo,
                sidesOn: on,
                recording: false,
                hyperDormant: false
            )
        }
        #expect(hint("rcmd+h", on: false) == ModifierSidesWords.eitherSideHint)
        #expect(hint("rcmd+h", on: true) == nil)
        #expect(hint("cmd+h", on: false) == nil)
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

    @Test("every recorder mount hands the sides down to the field")
    func mountsWireTheSides() throws {
        let tree = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let files = try FileManager.default
            .subpathsOfDirectory(atPath: tree.path)
            .filter { $0.hasSuffix(".swift") }
        var mounts = 0
        for file in files {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: tree.appendingPathComponent(file),
                    encoding: .utf8
                )
            )
            guard source.contains("RecorderCoordinator(") else {
                continue
            }
            mounts += 1
            #expect(source.contains(".recorderKeys(model)"), "\(file)")
        }
        // Non-vacuity: the Shortcuts section and a lens page.
        #expect(mounts >= 2)
        let helper = SourceScan.stripComments(
            try String(
                contentsOf: tree.appendingPathComponent(
                    "Settings/Components/Keybindings/"
                        + "KeybindingOverrideEnvironment.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(
            helper.contains(
                ".environment(\\.recorderSides, model.recorderSides)"
            )
        )
        let field = SourceScan.stripComments(
            try String(
                contentsOf: tree.appendingPathComponent(
                    "Settings/Components/Keybindings/Recorder/"
                        + "KeyRecorderField.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(field.contains("sides: recorderSides,"))
    }
}
