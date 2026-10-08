import AppKit
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Home's lower half (#1536): the three community links point at
/// `SupportLinks`' URLs and nowhere else, the marks ship as
/// template images, the footer's About goes through the shell's
/// action rather than a sheet of the strip's own, and the footer
/// carries the tour's permanent door (#1754).
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
            return try SourceScan.blankedSource(at: url)
        }
    }

    @Test("The three links are SupportLinks', each drawn once")
    func linksAreTheSupportLinks() throws {
        let source = try strip
        for needle in [
            "url:SupportLinks.discord", "url:SupportLinks.gitHub",
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

    @Test("The Discord link is the server invite, on discord.gg")
    func discordLinkIsTheServer() {
        #expect(SupportLinks.discord.host == "discord.gg")
        #expect(SupportLinks.discord.pathComponents.count == 2)
        #expect(SupportLinks.website.host == "kiwidesk.kiwicanopy.com")
    }

    @Test("The marks ship, and as template images")
    func marksAreTemplates() throws {
        for (name, mark) in [
            ("MarkDiscord", BrandAssets.markDiscord),
            ("MarkGitHub", BrandAssets.markGitHub),
            ("MarkKofi", BrandAssets.markKofi),
        ] {
            let image = try #require(mark, Comment(rawValue: name))
            #expect(image.isTemplate, Comment(rawValue: name))
        }
    }

    /// The banner's door retires after one use, so the footer is
    /// the tour's permanent one (#1754): it replays the tour where
    /// the banner does, never through the grant-step door, and it
    /// sits before About.
    @Test("The footer carries the tour's permanent door, before About")
    func footerCarriesTheTourDoor() throws {
        let source = try strip.split(whereSeparator: \.isWhitespace)
            .joined()
        let tour = try #require(
            source.range(of: "Button(action:{model.onShowTour()})")
        )
        let about = try #require(source.range(of: "Button(action:openAbout)"))
        #expect(tour.upperBound < about.lowerBound)
    }

    /// One permanent door (#1754 ruling): the tour replays from
    /// the first-run banner and the footer, and nowhere else, so a
    /// second standing door cannot appear beside them unruled.
    @Test("The tour replays from the banner and the footer only")
    func tourDoorsAreRuled() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: root)
        #expect(files.count > 50)
        var callers: Set<String> = []
        for url in files {
            let text = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            if text.contains(".onShowTour()") {
                callers.insert(url.lastPathComponent)
            }
        }
        #expect(
            callers == ["HomeFirstRunBanner.swift", "HomeSupportStrip.swift"]
        )
    }

    @Test("About is the shell's action, not a sheet of the strip's")
    func aboutGoesThroughTheShell() throws {
        let source = try strip
        #expect(source.contains("@Environment(\\.openAbout)"))
        #expect(!source.contains(".sheet("))
    }
}
