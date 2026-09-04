import Foundation
import Testing

@testable import KiwiDesk

/// One refusal cue (#1255): a blocked action DRAWS, and a drawn
/// pill may also sound.
///
/// The invariant that needs a guard is the placement, not the
/// sound: `soundRefusal()` is called from the pill-DRAWING
/// seams, never from the refusal funnels. A sound that can fire
/// without a pill re-creates the defect this replaced — a
/// refusal audible but invisible — and the sticky family is
/// where it would happen, since its pill is gated on
/// `sticky.mark` and draws nothing when the mark is off.
@Suite("Refusal cue seam")
struct RefusalCueSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func core(_ file: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "Sources/KiwiDeskCore/\(file)"
                ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    /// Every site that sounds is a site that has just drawn, or
    /// is about to in the same statement.
    @Test("the sound is spoken only where a pill is drawn")
    func soundSitsWithTheDrawing() throws {
        let pill = try Self.core("App/KiwiCore+SizeLimitPill.swift")
        let sticky = try Self.core("App/KiwiCore+StickyMarks.swift")
        // The size family: inside the one drawing helper, so
        // every refusal in that file inherits it by construction
        // rather than by a line each.
        #expect(
            pill.contains(
                "borders.flashSizeLimitPill(window:window,"
                    + "frame:frame,text:text)soundRefusal()"
            )
        )
        // The sticky family draws behind its own `sticky.mark`
        // gate, so the sound sits INSIDE that gate — with the
        // mark off these refusals are silent, not audible-only.
        #expect(sticky.occurrences(of: "soundRefusal()") == 3)
        for gate in [
            "guardtiler.settings.stickyStyle.mark",
            "soundRefusal()stickyMarks.flash(",
        ] {
            #expect(
                sticky.contains(gate),
                Comment(rawValue: "sticky cue seam lost: \(gate)")
            )
        }
    }

    /// Nothing may sound from a refusal FUNNEL: that is one
    /// indirection above the drawing, where the mark gate has
    /// not been consulted yet.
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
        var joined = ""
        for file in try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore"
            )
        ) {
            joined += SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
        }
        #expect(!joined.isEmpty)
        #expect(!joined.contains("cueUnsupportedCommand"))
        // `NSSound.beep()` lives in exactly one place, which is
        // what keeps "a sound follows a pill" checkable at all.
        #expect(joined.occurrences(of: "NSSound.beep()") == 1)
    }
}
