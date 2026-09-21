import AppKit
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Home's lower half (#1536): the three community links point at
/// `SupportLinks`' URLs and nowhere else, the marks ship as
/// template images, and the footer's About goes through the
/// shell's action rather than a sheet of the strip's own.
///
/// `@MainActor` for `BrandAssets`' image loads; nothing else.
@Suite("Home support strip")
@MainActor
struct HomeSupportStripTests {
    private var strip: String {
        get throws {
            let url = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Home/HomeSupportStrip.swift"
                )
            return SourceScan.blankingCommentsAndLiterals(
                try String(contentsOf: url, encoding: .utf8)
            )
        }
    }

    @Test("The three links are SupportLinks', each drawn once")
    func linksAreTheSupportLinks() throws {
        let source = try strip
        for needle in [
            "url:SupportLinks.telegram", "url:SupportLinks.gitHub",
            "url:SupportLinks.koFi",
        ] {
            #expect(
                source.split(whereSeparator: \.isWhitespace).joined()
                    .occurrences(of: needle) == 1,
                Comment(rawValue: needle)
            )
        }
        // No URL is spelled beside the strip: a link is a
        // `SupportLinks` constant or it does not exist.
        #expect(!source.contains("URL(string:"))
    }

    @Test("The Telegram link is the group's invite, on t.me")
    func telegramLinkIsTheGroup() {
        #expect(SupportLinks.telegram.host == "t.me")
        #expect(SupportLinks.telegram.path.hasPrefix("/+"))
        #expect(SupportLinks.website.host == "kiwidesk.kiwicanopy.com")
    }

    @Test("The marks ship, and as template images")
    func marksAreTemplates() {
        for (name, mark) in [
            ("MarkTelegram", BrandAssets.markTelegram),
            ("MarkGitHub", BrandAssets.markGitHub),
            ("MarkKofi", BrandAssets.markKofi),
        ] {
            let image = try? #require(mark, Comment(rawValue: name))
            #expect(image?.isTemplate == true, Comment(rawValue: name))
        }
    }

    @Test("About is the shell's action, not a sheet of the strip's")
    func aboutGoesThroughTheShell() throws {
        let source = try strip
        #expect(source.contains("@Environment(\\.openAbout)"))
        #expect(!source.contains(".sheet("))
    }
}
