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
        // And the speaker is reached only THROUGH that gate. The
        // count is read off the gate's own body rather than
        // restated (#1021, guard-prover 2026-09-05): a literal
        // here is retired by bumping it, which is exactly what a
        // second caller would do.
        let gate = try SourceScan.functionBody(
            of: "soundIfDrawn",
            in: "KiwiCore+SizeLimitPill.swift",
            under: "App"
        )
        let spoken = gate.occurrences(of: "soundRefusal()")
        #expect(spoken == 1)
        #expect(
            joined.occurrences(of: "soundRefusal()") == spoken + 1,
            Comment(
                rawValue: "a caller reached the speaker without "
                    + "passing a drawing's verdict (the +1 is "
                    + "its own declaration)"
            )
        )
    }

    /// The other direction, which the count above cannot see: a
    /// cue site that DRAWS and never offers the sound passes
    /// every clause there, since dropping the wrapper drops both
    /// sides of the derivation (guard-prover 2026-09-05).
    ///
    /// It matters because that is the direction the toggle's
    /// usefulness lives in — a refusal silently exempted from
    /// `refusal.sound` is a switch that does less than it says.
    @Test("every refusal's own drawing offers the sound")
    func everyDrawingIsOffered() throws {
        let pill = try Self.core("App/KiwiCore+SizeLimitPill.swift")
        let sticky = try Self.core("App/KiwiCore+StickyMarks.swift")
        // The one deliberate exemption, named by its own
        // spelling rather than counted: a paired refusal draws a
        // SECOND pill on the window that cannot move, and one
        // refusal sounds once. Since #1258 the pairing is the
        // renderer's (`ResizeRefusal.secondPill`), so the
        // exemption is one site rather than one per refusal.
        let anchorPill = "flashSizeLimitPill(second.window,"
        #expect(pill.occurrences(of: anchorPill) == 1)
        let unsounded =
            pill.occurrences(of: "flashSizeLimitPill(")
            - pill.occurrences(of: "funcflashSizeLimitPill(")
            - pill.occurrences(of: "borders.flashSizeLimitPill(")
            - pill.occurrences(
                of: "soundIfDrawn(flashSizeLimitPill("
            )
        #expect(
            unsounded == pill.occurrences(of: anchorPill),
            Comment(
                rawValue: "a size refusal draws without offering "
                    + "the sound — wrap it in soundIfDrawn, or "
                    + "name it beside the anchor pill"
            )
        )
        // The sticky family has no exemption at all.
        #expect(
            sticky.occurrences(of: "stickyMarks.flash(")
                == sticky.occurrences(
                    of: "soundIfDrawn(stickyMarks.flash("
                )
        )
    }

    /// The funnel may not reach the speaker except through a
    /// drawing's own verdict.
    ///
    /// Until #1258 this read "nothing may sound from a funnel at
    /// all", because the funnel sat one indirection ABOVE the
    /// drawing and neither primitive had decided whether it
    /// could draw. The redesign made the funnel the drawing site
    /// itself — one place where a refusal becomes a pill, a
    /// bump and a sound — so the shape to hold is no longer
    /// "silent" but "never ahead of the verdict": every sound in
    /// that body is `soundIfDrawn` over a drawing call, and the
    /// bare speaker appears nowhere in it.
    @Test("the funnel never sounds ahead of its drawing")
    func funnelSoundsOnlyOnAVerdict() throws {
        // Whitespace-stripped like every other needle here: the
        // funnel's call spans four lines.
        let body = Self.stripped(
            try SourceScan.functionBody(
                of: "cueResizeRefusal",
                in: "KiwiCore+SizeLimitPill.swift",
                under: "App"
            )
        )
        #expect(!body.isEmpty)
        #expect(
            !body.contains("soundRefusal()"),
            Comment(
                rawValue: "the funnel reached the speaker "
                    + "directly, ahead of any drawing's verdict"
            )
        )
        // Every offer it makes is over a drawing call, so the
        // verdict passed is the drawing's own.
        #expect(
            body.occurrences(of: "soundIfDrawn(")
                == body.occurrences(
                    of: "soundIfDrawn(flashSizeLimitPill("
                ),
            Comment(
                rawValue: "the funnel offered the sound on "
                    + "something other than a drawing's return"
            )
        )
        #expect(body.occurrences(of: "soundIfDrawn(") == 1)
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
