import Foundation
import Testing

@testable import KiwiDesk

/// The SHAPE of the #2059 title wiring: one writer of the window's
/// title, fired only by area navigation and the language. The
/// behaviour suite (`SettingsWindowTitleTests`) cannot see a later
/// caller that retitles on a search or a panel selection.
@Suite("Settings window title wiring (#2059)")
struct SettingsWindowTitleWiringTests {
    private static let gui = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk")

    /// Comment-stripped, whitespace-squashed source per GUI file.
    private static func sources(
        under directory: URL = gui
    ) throws -> [String: String] {
        var result: [String: String] = [:]
        for url in try SourceScan.swiftSources(under: directory) {
            let text = try SourceScan.strippedSource(at: url)
            result[url.lastPathComponent] =
                text.split(whereSeparator: \.isWhitespace).joined()
        }
        return result
    }

    private static func count(
        _ needle: String,
        in sources: [String: String]
    ) -> [String: Int] {
        sources.compactMapValues { text in
            let hits = text.components(separatedBy: needle).count - 1
            return hits > 0 ? hits : nil
        }
    }

    @Test("Only the destination, the language and the wiring retitle")
    func titleFiresOnlyFromAreaAndLanguage() throws {
        let sites = Self.count("onWindowTitle?(", in: try Self.sources())
        #expect(
            sites == [
                "SettingsModel.swift": 2,
                "SettingsModel+Language.swift": 1,
            ]
        )
    }

    @Test("SettingsWindowTitle is the one title writer")
    func oneTitleWriter() throws {
        let sources = try Self.sources()
        #expect(
            Self.count("onWindowTitle=", in: sources)
                == ["SettingsWindowTitle.swift": 1]
        )
        let writers = Self.count("window?.title=", in: sources)
            .merging(
                Self.count("window.title=", in: sources),
                uniquingKeysWith: +
            )
        #expect(writers["SettingsWindowTitle.swift"] == 1)
        #expect(writers["SettingsWindowController.swift"] == nil)
        let settings = try Self.sources(
            under: Self.gui.appendingPathComponent("Settings")
        )
        #expect(Self.count(".navigationTitle(", in: settings).isEmpty)
    }

    @Test("The controller wires the follow where it builds the window")
    func controllerWiresTheFollow() throws {
        let sources = try Self.sources()
        #expect(
            Self.count(
                "SettingsWindowTitle.follow(model,in:window)",
                in: sources
            ) == ["SettingsWindowController.swift": 1]
        )
    }
}
