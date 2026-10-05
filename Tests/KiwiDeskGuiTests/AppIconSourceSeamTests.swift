import Foundation
import Testing

/// An app's icon has one source in Core, `BarIconCache` (#1901):
/// the LaunchServices read is a round trip on the main actor, and an
/// app activation invalidates every retained `NSRunningApplication`
/// (#1936), so a second reader pays the read again on the path it
/// sits on. The Monocle flip's card was that second reader.
///
/// Scope: the spellings that read `.icon` straight off a running
/// application — a constructed one, the workspace's frontmost or
/// menu-bar owner, or one picked off a `runningApplications` list
/// in one member chain, wrapped or not. A read through a variable
/// holding one is not seen; review owns that case.
@Suite("App icon source seam (#1901)")
struct AppIconSourceSeamTests {
    private static let core = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// The one file that may read an icon off a running application.
    static let allowed = ["BarIconCache.swift"]

    private static let pattern =
        #"(NSRunningApplication\s*\([^)]*\)|frontmostApplication"#
        + #"|menuBarOwningApplication)\s*\??\s*\.icon\b"#
        + #"|runningApplications(\s*\??\s*\.\w+(\([^)]*\))?)*?"#
        + #"\s*\??\s*\.icon\b"#

    @Test("only the icon cache reads an icon off a running app")
    func iconReadsRouteThroughTheCache() throws {
        let regex = try NSRegularExpression(pattern: Self.pattern)
        var readers: [String] = []
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = try SourceScan.strippedSource(at: file)
            let range = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, range: range) != nil {
                readers.append(file.lastPathComponent)
            }
        }
        // The cache's own read keeps the needle honest: a pattern
        // that matched nothing would pass every tree.
        #expect(readers.sorted() == Self.allowed, "found \(readers)")
    }
}
