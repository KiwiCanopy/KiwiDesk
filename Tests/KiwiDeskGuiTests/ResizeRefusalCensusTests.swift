import Foundation
import Testing

/// Every refused resize is CLASSIFIED (#1258): each `.fail` a
/// resize path can return either cues the user or is named here
/// as one only a machine reads.
///
/// Scope, stated because the suite's name over-promises: it
/// reads `.fail`-SHAPED refusals. A path that refuses by
/// returning `.ok()` after a write nothing renders is invisible
/// here — which is exactly the shape of the fifth site #1258
/// found, so this register is one net rather than the net.
///
/// A hand-listed set of arms is what let that site survive the
/// change that went looking for it — #1258 shipped
/// with four wirings and a census in an issue comment, and the
/// empty-stack-zone case was found by review afterwards, drawing
/// "Minimum window size reached" on a window filling the screen.
/// So the register is derived from source: a `.fail` added to a
/// resize path reds this until its author says which it is.
@Suite("Resize refusal census (#1258)")
struct ResizeRefusalCensusTests {
    /// The directory every resize verb refuses from. DERIVED
    /// rather than hand-listed: a register whose roots are typed
    /// out is a register a new file joins silently, which is the
    /// failure this suite exists to close one level down
    /// (gui.md's root-coverage convention).
    static let directory = "Sources/KiwiDeskCore/Commands"

    /// A file is in scope when it names a resize verb — every
    /// `KiwiCore+Resize*` and the track's own writer file, plus
    /// the shared writers, which refuse too.
    static func inScope(_ name: String) -> Bool {
        name.hasSuffix(".swift")
            && (name.contains("Resize") || name.contains("Ratio"))
    }

    /// Every refusal a resize path returns, by the FIRST literal
    /// of its message, and what the user gets. `nil` means the
    /// press is deliberately wordless, and the value says why —
    /// which is the whole register: a wordless refusal that no
    /// one argued for is the defect this suite exists to catch.
    ///
    /// The keys are message fragments rather than line numbers
    /// so a moved guard does not red, and a REWORDED one does:
    /// the wording is what the reason below is about.
    static let classified: [String: String] = [
        // Cued — the user sees a pill.
        "resize not supported in ":
            "layoutHasNoResize — monocle, grid, floating (#1255)",
        "no \\(axis) parameter for this arrangement":
            "noAxisHere — the other axis divides (#1255)",
        "focused window is alone in its column":
            "nothingToDivide — the column has one member (#1258)",
        "only one track":
            "nothingToDivide — the track set has one member (#1258)",
        "the focused window fills its track along ":
            "nothingToDivide — the track has one member (#1258)",
        // Wordless, deliberately: no window to draw on, or a
        // caller that is not a person.
        "expected a boolean":
            "argument parse — a CLI/IPC contract, never a gesture",
        "expected axis (x|y) and delta":
            "argument parse — a CLI/IPC contract, never a gesture",
        "no active space":
            "nothing on screen to draw a pill on",
        "no focused tiled window":
            "the focus takes no part in this layout — a "
            + "native-fullscreen (#670) or elsewhere-rendering "
            + "sticky (#445) window, which effectiveTiledMembers "
            + "drops. It HAS a frame to draw on; what it lacks "
            + "is a partition to be refused from",
        "unknown window":
            "the id is gone; nothing to draw on",
        "track has no local window":
            "every member is a visiting traveler; #414's rule",
        "the focused window is visiting from ":
            "a traveler's share write is refused (#308); the "
            + "sticky mark carries this one, not the pill",
    ]

    private func source(_ path: String) throws -> String {
        let root = SourceScan.repoRoot(from: #filePath)
        let text = try SourceScan.strippedSource(
            at: root.appendingPathComponent(path)
        )
        // Fail shut: an unreadable file would pass every needle.
        try #require(!text.isEmpty, "\(path) read empty")
        return text
    }

    /// The first string literal of each `.fail(` in a file, and
    /// what it could not read.
    ///
    /// The literal must open IMMEDIATELY after the paren: a
    /// `.fail(reason)` taking a variable would otherwise harvest
    /// the next literal anywhere downstream and file an
    /// unrelated sentence under a classified key — measured
    /// green on a probe (guard-prover). Those are counted as
    /// `opaque` instead, and one is a red: the register cannot
    /// classify what it cannot read.
    private func refusals(
        in text: String
    ) -> (literals: [String], opaque: Int) {
        var found: [String] = []
        var opaque = 0
        var rest = Substring(text)
        while let hit = rest.range(of: ".fail(") {
            rest = rest[hit.upperBound...]
            let head = rest.drop(while: { $0 == " " || $0 == "\n" })
            guard head.first == "\"" else {
                opaque += 1
                continue
            }
            let after = head.index(after: head.startIndex)
            guard let close = head[after...].firstIndex(of: "\"")
            else { break }
            found.append(String(head[after..<close]))
            rest = head[close...]
        }
        return (found, opaque)
    }

    @Test("Every resize refusal is cued or argued")
    func everyRefusalIsClassified() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(Self.directory)
        let names = try FileManager.default
            .contentsOfDirectory(atPath: root.path)
            .filter(Self.inScope)
            .sorted()
        // Fail shut on the walk itself.
        #expect(names.count >= 6, "resize files not found")
        var seen: Set<String> = []
        for name in names {
            let text = try source(
                "\(Self.directory)/\(name)"
            )
            let read = refusals(in: text)
            #expect(
                read.opaque == 0,
                """
                \(name) refuses with a message this register \
                cannot read — it must be a literal, or the \
                register silently files someone else's sentence.
                """
            )
            for message in read.literals {
                seen.insert(message)
                #expect(
                    Self.classified[message] != nil,
                    """
                    \(name) refuses with "\(message)" and this \
                    register does not say what the user gets. \
                    Cue it, or add it with the reason it stays \
                    wordless (#1258).
                    """
                )
            }
        }
        // The register may not outlive its call sites either: a
        // stale entry is a claim about code that is gone.
        for message in Self.classified.keys {
            #expect(
                seen.contains(message),
                """
                The register names "\(message)", which no resize \
                path returns any more — drop the entry.
                """
            )
        }
        // Non-vacuity, derived rather than a hand-carried floor.
        #expect(seen.count == Self.classified.count)
    }
}
