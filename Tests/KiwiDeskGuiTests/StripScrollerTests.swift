import Foundation
import Testing

/// A sideways strip in Settings keeps the platform's scroller, which
/// a mouse user needs to reach what it cuts (#2901). Scans source
/// off the main actor; whether macOS draws it is a device check.
///
/// Both walks read every site's arguments instead of matching a hide's
/// spelling. They trade reach for that: a modifier wrapped in a helper
/// that takes the visibility as a value is not seen at the wrapper's
/// caller.
@Suite("Settings strip scroller")
struct StripScrollerTests {
    private static func settingsSources() throws -> [(String, String)] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        return try SourceScan.swiftSources(under: root).map { url in
            let source = try SourceScan.strippedSource(at: url)
            return (
                url.lastPathComponent,
                source.split(whereSeparator: \.isWhitespace).joined()
            )
        }
    }

    /// What follows each occurrence of `needle`.
    private static func tails(of needle: String, in source: String)
        -> [Substring]
    {
        source.components(separatedBy: needle).dropFirst().map {
            Substring($0)
        }
    }

    @Test("no Settings scroll view hides its scroller by argument")
    func noHiddenArgument() throws {
        let sources = try Self.settingsSources()
        #expect(sources.contains { $0.1.contains("ScrollView(.horizontal") })
        for (name, source) in sources {
            for tail in Self.tails(of: "showsIndicators:", in: source) {
                #expect(tail.hasPrefix("true"), "\(name) hides a scroller")
            }
        }
    }

    /// The modifier is documented to reach nested scroll views, so any
    /// hide beyond the vertical axis also hides a strip below it.
    @Test("a hiding modifier names only the vertical axis")
    func hidingIsVerticalOnly() throws {
        let allowed = [".automatic", ".visible", ".hidden,axes:.vertical)"]
        var sites = 0
        for (name, source) in try Self.settingsSources() {
            for tail in Self.tails(of: ".scrollIndicators(", in: source) {
                sites += 1
                #expect(
                    allowed.contains { tail.hasPrefix($0) },
                    "\(name) hides more than the vertical axis"
                )
            }
        }
        #expect(sites > 0)
    }
}
