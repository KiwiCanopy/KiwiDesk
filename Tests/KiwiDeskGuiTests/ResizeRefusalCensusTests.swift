import Foundation
import Testing

/// Every refused resize is CLASSIFIED (#1258): each `.fail` a
/// resize path can return either cues the user or is named here
/// as one only a machine reads.
///
/// A hand-listed set of arms is what let the fifth silent site
/// survive the change that went looking for it — #1258 shipped
/// with four wirings and a census in an issue comment, and the
/// empty-stack-zone case was found by review afterwards, drawing
/// "Minimum window size reached" on a window filling the screen.
/// So the register is derived from source: a `.fail` added to a
/// resize path reds this until its author says which it is.
@Suite("Resize refusal census (#1258)")
struct ResizeRefusalCensusTests {
    /// The files a resize verb can refuse from.
    static let paths = [
        "Sources/KiwiDeskCore/Commands/KiwiCore+Resize.swift",
        "Sources/KiwiDeskCore/Commands/KiwiCore+ResizeBsp.swift",
        "Sources/KiwiDeskCore/Commands/KiwiCore+ResizeStack.swift",
        "Sources/KiwiDeskCore/Commands/KiwiCore+ResizeFloating.swift",
        "Sources/KiwiDeskCore/Commands/KiwiCore+ResizeScrollSlot.swift",
        "Sources/KiwiDeskCore/Commands/KiwiCore+TrackResize.swift",
    ]

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
        "the stack zone is empty":
            "nothingToDivide — neither axis divides (#1258)",
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
            "no window to draw the pill on",
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

    /// The first string literal of each `.fail(` in a file.
    private func refusals(in text: String) -> [String] {
        var found: [String] = []
        var rest = Substring(text)
        while let hit = rest.range(of: ".fail(") {
            rest = rest[hit.upperBound...]
            guard let open = rest.firstIndex(of: "\"") else { break }
            let after = rest.index(after: open)
            guard let close = rest[after...].firstIndex(of: "\"")
            else { break }
            found.append(String(rest[after..<close]))
            rest = rest[close...]
        }
        return found
    }

    @Test("Every resize refusal is cued or argued")
    func everyRefusalIsClassified() throws {
        var seen: Set<String> = []
        for path in Self.paths {
            for message in refusals(in: try source(path)) {
                seen.insert(message)
                #expect(
                    Self.classified[message] != nil,
                    """
                    \(path) refuses with "\(message)" and this \
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
        // The scan itself must have found something.
        #expect(seen.count >= 12)
    }
}
