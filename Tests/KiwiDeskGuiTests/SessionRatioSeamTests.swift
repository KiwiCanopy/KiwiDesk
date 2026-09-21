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
/// vanished one reds too. Fails OPEN for a store reached through
/// a name the needles do not spell — a `Space` copied out under
/// another name and mutated there, an `inout` hand-off of a
/// field rather than the store — and for a member chain broken
/// BEFORE the field (`$0.sessionRatios` alone on a line), which
/// the formatter does not produce; review carries both.
@Suite("Session ratio write seam (#764)")
struct SessionRatioSeamTests {
    /// A write: `sessionRatios`, optionally one member or a
    /// key path away, assigned on this line or at its end (the
    /// formatter breaks after `=`), or handed out `inout`
    /// through whatever path reaches it.
    private static let write = try! NSRegularExpression(
        pattern:
            #"sessionRatios(\.\w+|\[[^\]]*\])?\s*=(\s|$)"#
            + #"|&[\w$\[\]!?.]*sessionRatios\b"#
    )

    /// Files that may spell a write, with today's count and why.
    private let allowed: [String: Int] = [
        // The seam: the four `write*` and the two clears.
        "Tiling/KiwiCore+SessionRatioWrite.swift": 6,
        // The model's own init and `resetSizing`.
        "Models/SpaceModel.swift": 2,
        // The mode-change reseed (#458).
        "State/WorkspaceManager.swift": 1,
    ]

    /// Writes per line; a read (`space.sessionRatios.splitRatioH`
    /// on the right of `let`, the overlay's `if let value =`) has
    /// no `=` after the store and is not matched. `let
    /// sessionRatios = …` would match and is fail-closed.
    private static func writes(in source: String) -> Int {
        source.split(separator: "\n").reduce(0) { count, line in
            let text = String(line)
            let range = NSRange(text.startIndex..., in: text)
            return count
                + (write.firstMatch(in: text, range: range) == nil
                    ? 0 : 1)
        }
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
