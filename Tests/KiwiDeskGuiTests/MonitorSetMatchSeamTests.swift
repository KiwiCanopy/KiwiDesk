import Foundation
import Testing

/// A monitor set is an order since #3647, so `monitors` compared
/// with `==` is order-sensitive: a stored order against the live or
/// a sorted list differs on the same screens and the match fails
/// silently. Matching goes through `MonitorSet.matches` or
/// `sortedKey`, homed in `MonitorSet.swift`; this scan reds a raw
/// compare anywhere else in either source tree. It sees `.monitors`
/// beside `==` or `!=` on one line, after stripping comments and
/// whitespace, sparing a member read off it (`monitors.count`); and
/// the pre-#3647 idiom `monitors.sorted()` and a `Set` built from
/// `map(\.monitors)`, both `sortedKey`'s. A compare spread over
/// lines, through another name, through `contains`, a Dictionary
/// keyed by the order, or a synthesized `==` of a whole `MonitorSet`
/// or `Profile` is review's.
@Suite("Monitor set matching has one home (#3647)")
struct MonitorSetMatchSeamTests {
    @Test("no raw monitors compare outside MonitorSet")
    func noRawCompare() throws {
        let repo = SourceScan.repoRoot(from: #filePath)
        var files: [URL] = []
        for tree in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            files += try SourceScan.swiftSources(
                under: repo.appendingPathComponent(tree)
            )
        }
        #expect(files.count > 100, "the scan found the trees")
        let compare = try NSRegularExpression(
            pattern: #"\.monitors(==|!=)|(==|!=)[\w.?]*\.monitors(?![\w.])|"#
                + #"\.monitors\.sorted\(\)|Set\([\w.$]*map\(\\\.monitors\)"#
        )
        var found: [String] = []
        for file in files where file.lastPathComponent != "MonitorSet.swift" {
            for line in try SourceScan.strippedSource(at: file)
                .split(separator: "\n")
            {
                let text = String(line.filter { !$0.isWhitespace })
                let range = NSRange(text.startIndex..., in: text)
                if compare.firstMatch(in: text, range: range) != nil {
                    found.append(file.lastPathComponent)
                }
            }
        }
        #expect(found.isEmpty, "\(found)")
    }
}
