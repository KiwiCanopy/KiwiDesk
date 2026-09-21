import Foundation
import Testing

/// A `sessionRatios` write lives in the interactive-resize seam
/// (`KiwiCore+SessionRatioWrite`) or in the model's own reseeds
/// (#458, #764). The per-space `_override` setters used to spell
/// the clear raw beside their call sites, which is the form a
/// fifth setter copies; a raw write that forgets the clear, or
/// clears the wrong field, leaves an explicit write shadowed with
/// nothing red. The scan counts the spellings that reach the
/// store under `Sources/KiwiDeskCore` and pins each file outside
/// the seam to its count, so a new site reds on arrival and a
/// vanished one reds too. Fails OPEN for a write through a local
/// copy of a `Space` assigned back whole, which review carries.
@Suite("Session ratio write seam (#764)")
struct SessionRatioSeamTests {
    /// The spellings that write or hand out the store for
    /// writing: a member assignment, a whole-value assignment,
    /// and an `inout` hand-off.
    private static let needles = [
        "sessionRatios.", "sessionRatios = ", "&$0.sessionRatios",
    ]

    /// Files that may spell a write, with today's count and why.
    private let allowed: [String: Int] = [
        // The seam: the four `write*` and the two clears.
        "Tiling/KiwiCore+SessionRatioWrite.swift": 6,
        // The model's own init and `resetSizing`.
        "Models/SpaceModel.swift": 2,
        // The mode-change reseed (#458).
        "State/WorkspaceManager.swift": 1,
    ]

    /// Occurrences that are writes: a `.` member read — `space.
    /// sessionRatios.splitRatioH` on the right of `let`, the
    /// overlay's `if let value =` — is skipped by requiring an
    /// assignment on the same line or the `&` hand-off.
    private static func writes(in source: String) -> Int {
        var count = 0
        for line in source.split(separator: "\n") {
            let text = String(line)
            guard needles.contains(where: { text.contains($0) })
            else { continue }
            if text.contains("&$0.sessionRatios")
                || text.range(
                    of: #"sessionRatios(\.\w+)? = "#,
                    options: .regularExpression
                ) != nil
            {
                count += 1
            }
        }
        return count
    }

    @Test("sessionRatios writes outside the seam stay pinned")
    func writesStayInTheSeam() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let key = String(file.path.dropFirst(prefix.count))
            let source = try SourceScan.strippedSource(at: file)
            let hits = Self.writes(in: source)
            guard hits > 0 else { continue }
            counts[key] = hits
        }
        for (file, count) in counts.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) writes sessionRatios \(count)× — route it "
                + "through KiwiCore+SessionRatioWrite (#764) or "
                + "justify and pin it here"
            #expect(allowed[file] == count, Comment(rawValue: unlisted))
        }
        for (file, expected) in allowed {
            let vanished =
                "\(file) no longer writes sessionRatios \(expected)× "
                + "— re-pin or drop its entry"
            #expect(counts[file] == expected, Comment(rawValue: vanished))
        }
    }
}
