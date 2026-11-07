import Foundation
import Testing

/// Every row deletion takes its focus neighbour from the one
/// `DeletionFocus.neighbour` rule, read before the mutation
/// (#816). Spaces carried a private copy that would keep the old
/// answer through a retune of the rule (#3059). Off the main
/// actor: pure file reads.
@Suite("Deletion focus routes through one rule (#3059)")
struct DeletionFocusRoutingTests {
    /// The rule's next-else-previous step, whitespace removed:
    /// the shape a private copy of `DeletionFocus.neighbour` has.
    private static let ruleShape =
        #"\+1<(\w+)\.count\{return\1\[\w+\+1\]"#

    private static let home =
        "Sources/KiwiDesk/Settings/DeletionFocus.swift"

    @Test("removing a Space reads the shared rule before mutating")
    func spacesRemovalRoutesThroughTheRule() throws {
        let body = try SourceScan.functionBody(
            of: "removeSpace",
            in: "SpacesSection+Remove.swift",
            under: "Settings/Sections",
            root: "Sources/KiwiDesk"
        ).filter { !$0.isWhitespace }
        let read = body.range(
            of: "DeletionFocus.neighbour(after:space,in:displayedSpaces)"
        )
        let write = body.range(of: "model.removeSpace(space)")
        #expect(read != nil, "removeSpace bypasses DeletionFocus")
        #expect(write != nil, "removeSpace no longer removes")
        if let read, let write {
            #expect(
                read.lowerBound < write.lowerBound,
                "the neighbour is read after the mutation (#816)"
            )
        }
    }

    @Test("no Settings file carries its own copy of the rule")
    func noPrivateCopy() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let files = try SourceScan.swiftSources(
            under: root.appendingPathComponent("Sources/KiwiDesk")
        )
        #expect(files.count > 100, "the walk found too few files")
        let shape = try Regex(Self.ruleShape)
        var copies: [String] = []
        var homeMatched = false
        for file in files {
            let flat = try SourceScan.strippedSource(at: file)
                .filter { !$0.isWhitespace }
            guard flat.contains(shape) else { continue }
            if file.path.hasSuffix(Self.home) {
                homeMatched = true
            } else {
                copies.append(file.lastPathComponent)
            }
        }
        // Positive control: the needle still matches the rule
        // itself, so a reworded rule cannot leave this blind.
        #expect(homeMatched, "the needle no longer matches the rule")
        #expect(copies.isEmpty, "private copies: \(copies)")
    }
}
