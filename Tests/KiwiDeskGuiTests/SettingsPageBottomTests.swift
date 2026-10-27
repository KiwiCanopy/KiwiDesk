import Foundation
import Testing

@testable import KiwiDesk

/// Every Settings page ends clear of the floating save pill (#2688):
/// each section root's scroll content takes the one
/// `settingsPageBottom()`, and none pads its own bottom. Source
/// scans, off the main actor.
@Suite("Settings page bottom")
struct SettingsPageBottomTests {
    private static func sections() throws -> [(String, String)] {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings/Sections")
        return try FileManager.default
            .contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".swift") }
            .map { name in
                let source = try String(
                    contentsOf: dir.appendingPathComponent(name),
                    encoding: .utf8
                )
                return (
                    name,
                    SourceScan.stripComments(source)
                        .split(whereSeparator: \.isWhitespace)
                        .joined()
                )
            }
    }

    /// One modifier per page scroll view, counted per file, so a
    /// page that drops it reds even while another page keeps it.
    @Test("every section scroll view ends with the pill's room")
    func everyPageTakesTheInset() throws {
        let files = try Self.sections()
        let pages = files.filter { $0.1.contains("ScrollView{") }
        #expect(pages.count > 10)
        for (name, source) in pages {
            #expect(
                source.occurrences(of: "ScrollView{")
                    == source.occurrences(of: ".settingsPageBottom()"),
                Comment(rawValue: "\(name) scroll views vs insets")
            )
        }
        for (name, source) in files {
            #expect(
                !source.contains(".padding([.horizontal,.bottom],"),
                Comment(rawValue: "\(name) pads its own bottom")
            )
        }
    }
}
