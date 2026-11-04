import Foundation
import Testing

/// A sideways strip in Settings keeps the platform's scroller, which
/// a mouse user needs to reach what it cuts (#2901). Scans source
/// off the main actor; whether macOS draws it is a device check.
@Suite("Settings strip scroller")
struct StripScrollerTests {
    private static func settingsSources() throws -> [(String, String)] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        return try SourceScan.swiftSources(under: root).map { url in
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            return (
                url.lastPathComponent,
                source.split(whereSeparator: \.isWhitespace).joined()
            )
        }
    }

    /// `showsIndicators: false` on any axis is out too: a strip spelled
    /// with an axis variable would slip a needle naming `.horizontal`.
    @Test("no Settings scroll view hides its scroller by argument")
    func noHiddenArgument() throws {
        let sources = try Self.settingsSources()
        #expect(sources.contains { $0.1.contains("ScrollView(.horizontal") })
        for (name, source) in sources {
            #expect(
                !source.contains("showsIndicators:false"),
                "\(name) hides a scroller"
            )
        }
    }

    /// The modifier reaches nested scroll views, so a hide with no
    /// axes on a vertical scroller also hides a strip inside it.
    @Test("a hiding modifier names its axis")
    func hidingNamesItsAxis() throws {
        let sources = try Self.settingsSources()
        for (name, source) in sources {
            #expect(
                !source.contains(".scrollIndicators(.hidden)"),
                "\(name) hides every axis below it"
            )
        }
        let panel = sources.first { $0.0 == "SettingsDetailPanel.swift" }
        #expect(
            panel?.1.contains(".scrollIndicators(.hidden,axes:.vertical)")
                == true
        )
    }
}
