import Foundation
import Testing

@testable import KiwiDesk

/// One refusal cue (#1255): a blocked action DRAWS, and a drawn
/// pill may also sound.
///
/// The invariant that needs a guard is the placement, not the
/// sound: it is spoken from `soundIfDrawn`, which takes the
/// DRAWING's own verdict as its argument. A sound that can fire
/// without a pill re-creates the defect this replaced — a
/// refusal audible but invisible — and both primitives can
/// decline to draw: the size pill needs the private runtime, and
/// the sticky mark is gated on `sticky.mark`.
@Suite("Refusal cue seam")
struct RefusalCueSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func stripped(_ text: String) -> String {
        SourceScan.stripComments(text)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    private static func core(_ file: String) throws -> String {
        stripped(
            try String(
                contentsOf: root.appendingPathComponent(
                    "Sources/KiwiDeskCore/\(file)"
                ),
                encoding: .utf8
            )
        )
    }

    private static func tree(_ target: String) throws -> String {
        var joined = ""
        for file in try SourceScan.swiftSources(
            under: root.appendingPathComponent("Sources/\(target)")
        ) {
            joined += stripped(
                try String(contentsOf: file, encoding: .utf8)
            )
        }
        return joined
    }

    /// Every site that sounds hands in what the drawing returned,
    /// so the two cannot come apart at a call site.
    @Test("the sound is spoken only where a pill is drawn")
    func soundSitsWithTheDrawing() throws {
        let joined = try Self.tree("KiwiDeskCore")
        #expect(!joined.isEmpty)
        #expect(
            joined.contains(
                "funcsoundIfDrawn(_drew:Bool){ifdrew{soundRefusal()}}"
            ),
            Comment(
                rawValue: "the one gate between a drawing and a "
                    + "sound changed shape"
            )
        )
        // Derived rather than pinned (#1021): whatever the cue
        // sites number, EVERY one of them is a drawing call — so
        // the only `soundIfDrawn(` left over is its own
        // declaration.
        let drawn =
            joined.occurrences(
                of: "soundIfDrawn(flashSizeLimitPill("
            )
            + joined.occurrences(
                of: "soundIfDrawn(stickyMarks.flash("
            )
        #expect(drawn > 0)
        #expect(joined.occurrences(of: "soundIfDrawn(") == drawn + 1)
        // And the speaker is reached only through that gate: one
        // declaration, one call, both in the same file.
        #expect(joined.occurrences(of: "soundRefusal()") == 2)
    }

    /// Nothing may sound from a refusal FUNNEL: that is one
    /// indirection above the drawing, where neither primitive has
    /// decided whether it can draw.
    @Test("no refusal funnel sounds on its own")
    func funnelsStaySilent() throws {
        let pill = try Self.core("App/KiwiCore+SizeLimitPill.swift")
        #expect(!pill.isEmpty)
        #expect(
            pill.contains(
                "funccueResizeRefusal(_refusal:ResizeRefusal){"
                    + "keys.noteResizeRefusal()"
                    + "borders.onResizeRefusal(refusal)}"
            ),
            Comment(
                rawValue: "the refusal funnel gained a cue of "
                    + "its own — it runs before the drawing "
                    + "decided whether to draw"
            )
        )
    }

    /// The sound-only seam is gone: both of its cases draw now.
    @Test("nothing cues by sound alone any more")
    func noSoundOnlyCue() throws {
        let core = try Self.tree("KiwiDeskCore")
        #expect(!core.contains("cueUnsupportedCommand"))
        // In Core the beep lives in exactly one place, which is
        // what keeps "a sound follows a pill" checkable at all.
        #expect(core.occurrences(of: "NSSound.beep()") == 1)
        // The GUI's one beep is the settings row's own preview —
        // it plays the cue being described, next to no refusal.
        let gui = try Self.tree("KiwiDesk")
        let behavior = Self.stripped(
            try String(
                contentsOf: Self.root.appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Sections/"
                        + "BehaviorSection.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(behavior.occurrences(of: "NSSound.beep()") == 1)
        #expect(gui.occurrences(of: "NSSound.beep()") == 1)
    }
}
