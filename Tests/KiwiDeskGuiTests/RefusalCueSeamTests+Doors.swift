import Foundation
import Testing

@testable import KiwiDesk

/// The refusal cue seam's builder and door censuses (#1261, #1255):
/// an extension of the one suite, so a citation names it.
extension RefusalCueSeamTests {
    /// Whose floor a minimum pill names is derived by the
    /// builders, never handed in (#1261): every `appBound:` the
    /// builders' file spells is the one derivation's call, and
    /// no builder takes the verdict as a parameter. Derived
    /// rather than pinned (#1021) — whatever the builders
    /// number, each verdict is that call.
    @Test("a minimum pill's verdict is derived, never handed in")
    func appBoundIsDerivedByTheBuilders() throws {
        let pill = try Self.core("App/KiwiCore+SizeLimitPill.swift")
        let verdicts = pill.occurrences(of: "appBound:")
        #expect(verdicts > 0)
        #expect(
            verdicts
                == pill.occurrences(of: "appBound:minimumIsAppBound("),
            Comment(
                rawValue: "a builder spelled appBound: from "
                    + "something other than minimumIsAppBound — "
                    + "a call site is answering whose floor bound"
            )
        )
        // The builders may take a FLOOR the clamp adds beside the
        // setting (`raisedBy`), never the verdict itself: no
        // `func refuse…` signature — the text up to its body —
        // declares it.
        var builders = 0
        for piece in pill.components(separatedBy: "funcrefuse")
            .dropFirst()
        {
            let signature = piece.prefix { $0 != "{" }
            builders += 1
            #expect(
                !signature.contains("appBound"),
                Comment(
                    rawValue: "a builder declares appBound: — the "
                        + "verdict must be derived inside it"
                )
            )
        }
        #expect(builders > 0)
    }

    /// The sound-only seam is gone: both of its cases draw now.
    @Test("nothing cues by sound alone any more")
    func noSoundOnlyCue() throws {
        let core = try Self.tree("KiwiDeskCore")
        #expect(!core.contains("cueUnsupportedCommand"))
        // In Core the beep lives in exactly one place, which is
        // what keeps "a sound follows a pill" checkable at all.
        #expect(core.occurrences(of: "NSSound.beep()") == 1)
        // The GUI's two beeps refuse nothing: a settings preview,
        // and KiwiHub's dead ↩ chord (#2931, `JumpRefusalRowTests`).
        let gui = try Self.tree("KiwiDesk")
        let general = try Self.file(
            Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/"
                    + "GeneralSection+AppWide.swift"
            )
        )
        #expect(general.occurrences(of: "NSSound.beep()") == 1)
        #expect(gui.occurrences(of: "NSSound.beep()") == 2)
    }

    /// The door every refusal pill takes draws WITHOUT the sound,
    /// so its callers are named by file: the resize wrapper, whose
    /// own callers offer the sound above, and the window actions'
    /// cue, which lands after any hotkey fire (#1518), and
    /// KiwiVision's out-of-reach cue, which a profile switch draws
    /// rather than a press (#2103 ruling 16). A further caller
    /// would be a refusal silently exempt from `refusal.sound` —
    /// the defect this suite exists to catch.
    @Test("the unsounded pill door has its named callers")
    func pillDoorCallersAreNamed() throws {
        let core = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore"
        )
        var callers: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: core) {
            let text = try Self.file(file)
            let calls =
                text.occurrences(of: "flashRefusalPill(")
                - text.occurrences(of: "funcflashRefusalPill(")
            if calls > 0 { callers[file.lastPathComponent] = calls }
        }
        #expect(
            callers == [
                "KiwiCore+SizeLimitPill.swift": 1,
                "KiwiCore+WindowActions.swift": 1,
                "KiwiCore+VisionReach.swift": 1,
                // A bar's shortcut refused (#761), sounded
                // through `soundIfDrawn`, at the bar alone (#2567).
                "KiwiCore+ShelfRevealCue.swift": 1,
                // The pocket's refusals — sticky (#2446), a second
                // window (#2675), an app's own window (#2612) —
                // sounded through `soundIfDrawn`.
                "KiwiCore+Pocket.swift": 1,
                "KiwiCore+PocketWindow.swift": 1,
                "KiwiCore+PocketApp.swift": 1,
                // A Hyper press with nothing to do (#2480): silent
                // by ruling, on a window or else the shelf.
                "KiwiCore+HyperBarePress.swift": 2,
                // Maximize on a floating window (#2448): its only
                // cue, so it announces.
                "KiwiCore+Maximize.swift": 1,
            ],
            "found: \(callers)"
        )
        // And nothing goes around the door: the Borders primitive
        // is called once in Core, from the door's own body.
        var primitive = 0
        for file in try SourceScan.swiftSources(under: core) {
            primitive += try Self.file(file).occurrences(
                of: "borders.flashSizeLimitPill("
            )
        }
        let door = Self.stripped(
            try SourceScan.functionBody(
                of: "flashRefusalPill",
                in: "KiwiCore+SizeLimitPill.swift",
                under: "App"
            )
        )
        #expect(primitive == 1)
        #expect(door.occurrences(of: "borders.flashSizeLimitPill(") == 1)
        // The shelf twin's primitive likewise (#761): once, from its
        // own door's body.
        var shelfPrimitive = 0
        for file in try SourceScan.swiftSources(under: core) {
            shelfPrimitive += try Self.file(file).occurrences(
                of: "borders.flashShelfPill("
            )
        }
        let shelfDoor = Self.stripped(
            try SourceScan.functionBody(
                of: "flashRefusalPill",
                in: "KiwiCore+ShelfPill.swift",
                under: "App"
            )
        )
        #expect(shelfPrimitive == 1)
        #expect(shelfDoor.occurrences(of: "borders.flashShelfPill(") == 1)
    }
}
