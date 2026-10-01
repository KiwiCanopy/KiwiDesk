import AppKit
import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// "Next on my list" (#1813 ruling): what the window reads of the
/// site's `roadmap.json`, when it hides the list, and that the
/// What's new window draws it. The Markdown half is
/// `site/test-roadmap.mjs`'s.
@MainActor
@Suite("Next on my list (#1813)")
struct NextOnMyListTests {
    private static func data(_ json: String) -> Data { Data(json.utf8) }

    private static let valid = """
        {"format":1,"as_of":"2026-09-30","items":["One","Two"]}
        """

    private static func day(_ text: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return try #require(formatter.date(from: text))
    }

    @Test("reads the date as midnight UTC, and the items")
    func readsTheDocument() throws {
        let next = try #require(NextOnMyList.decode(Self.data(Self.valid)))
        #expect(next.asOf == (try Self.day("2026-09-30")))
        #expect(next.items == ["One", "Two"])
    }

    @Test("a key it does not know is ignored")
    func unknownKeysAreIgnored() {
        let grown = """
            {"format":1,"as_of":"2026-09-30","items":["One"],"later":[]}
            """
        #expect(NextOnMyList.decode(Self.data(grown))?.items == ["One"])
    }

    @Test("anything it cannot show reads as nothing")
    func unreadableReadsAsNothing() {
        for json in [
            #"{"format":2,"as_of":"2026-09-30","items":["One"]}"#,
            #"{"format":1,"items":[]}"#,
            #"{"format":1,"as_of":"2026-09-30","items":[]}"#,
            #"{"format":1,"items":["One"]}"#,
            #"{"format":1,"as_of":"soon","items":["One"]}"#,
            #"{"as_of":"2026-09-30","items":["One"]}"#,
            "not json",
        ] {
            #expect(NextOnMyList.decode(Self.data(json)) == nil, "\(json)")
        }
    }

    @Test("hidden once more than sixty days old, or dated ahead")
    func ageBoundsTheList() throws {
        let next = NextOnMyList(asOf: try Self.day("2026-09-30"), items: ["A"])
        let day: TimeInterval = 86_400
        #expect(next.current(at: next.asOf) == next)
        #expect(next.current(at: next.asOf + 60 * day) == next)
        #expect(next.current(at: next.asOf + 60 * day + 1) == nil)
        // A writer east of UTC dates the list a day early.
        #expect(next.current(at: next.asOf - day) == next)
        #expect(next.current(at: next.asOf - day - 1) == nil)
    }

    @Test("fetched beside the update feed")
    func fetchedBesideTheFeed() throws {
        let feed = try #require(
            URL(string: "https://kiwidesk.kiwicanopy.com/appcast.xml")
        )
        #expect(
            NextOnMyList.url(besideFeed: feed).absoluteString
                == "https://kiwidesk.kiwicanopy.com/roadmap.json"
        )
    }

    /// Through the mode, the layout and the Next tab (#1849): the
    /// window is measured over every tab, so a long list it is
    /// handed makes it taller.
    @Test("What's new draws the list in its Next tab")
    func whatsNewDrawsTheCard() throws {
        LocalizationManager.shared.select("en")
        let offer = UpdateOffer(
            version: "2.1.0",
            build: "2.1.0",
            installed: "2.0.0",
            released: nil,
            digest: UpdateNotesDigest(
                summary: "Summary.",
                cautions: [],
                groups: [
                    .init(
                        type: "fixed",
                        title: "Fixed",
                        entries: [.init(text: "A.", version: "2.1.0")]
                    )
                ],
                versions: ["2.1.0"],
                unreadable: []
            )
        )
        let next = NextOnMyList(
            asOf: try Self.day("2026-09-30"),
            items: (1...12).map { "Item \($0)" }
        )
        func height(_ next: NextOnMyList?) -> CGFloat {
            NSHostingView(
                rootView: UpdateWindowView(
                    offer: offer,
                    mode: .whatsNew(narration: nil, next: next) {},
                    measuring: true
                )
            ).fittingSize.height
        }
        #expect(height(next) > height(nil) + 80)
    }

    /// The Ko-fi line rides What's new and the up-to-date answer,
    /// never the offer, whose one decision is Install (#1849).
    @Test("the support line never sits beside an Install")
    func supportNeverInTheOffer() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath).appendingPathComponent(
                "Sources/KiwiDesk/Updates/UpdateNotesScroll.swift"
            )
        )
        #expect(
            source.contains(
                "NextOnMyListPanel(next: next, asksForSupport: whatsNew)"
            )
        )
        let window = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath).appendingPathComponent(
                "Sources/KiwiDesk/Updates/UpdateWindowView.swift"
            )
        )
        // The offer's layout passes `whatsNew: false`, the other two
        // `true`.
        let offer = try #require(
            window.components(separatedBy: "private struct UpdateOfferLayout")
                .last
        )
        #expect(offer.contains("whatsNew: false,"))
    }

    /// Everything inside a notes card is English like the notes
    /// (#1849): the card views spell no `L(`, so a later pass
    /// cannot translate a heading back over English lines.
    @Test("the notes' cards speak the notes' English")
    func cardsSpellNoLocalizedString() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Updates")
        for file in [
            "NextOnMyListPanel.swift", "UpdateNotesEnglish.swift",
        ] {
            let source = try SourceScan.strippedSource(
                at: root.appendingPathComponent(file)
            )
            #expect(!source.contains("L("), "\(file) localizes")
        }
        let groups = try SourceScan.strippedSource(
            at: root.appendingPathComponent("UpdateNotesGroups.swift")
        )
        // The panel and the list; the naming enum after them names
        // the strip's tabs, which ARE translated.
        let cards = try #require(
            groups.components(separatedBy: "enum UpdateNotesNaming").first
        )
        #expect(!cards.contains("L("))
        let markdown = try SourceScan.strippedSource(
            at: root.appendingPathComponent("UpdateNotesMarkdown.swift")
        )
        #expect(!markdown.contains("L("))
    }

    /// The Next pane names Discord and Ko-fi with the marks Home's
    /// support strip draws, through the one `BrandMark` both take,
    /// so the two surfaces cannot drift (#1863).
    @Test("the Next pane's links wear Home's brand marks")
    func linksWearHomesMarks() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let panel = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Updates/NextOnMyListPanel.swift"
            )
        )
        #expect(panel.contains("mark: BrandAssets.markDiscord"))
        #expect(panel.contains("mark: BrandAssets.markKofi"))
        let link = try SourceScan.strippedSource(
            at: root.appendingPathComponent("Updates/UpdateNotesScroll.swift")
        )
        #expect(link.contains("if let mark { BrandMark(image: mark"))
        let home = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Settings/Home/SupportLinkRow.swift"
            )
        )
        #expect(home.contains("BrandMark(image: mark)"))
        // One drawing: no second `Image(nsImage:` for a mark.
        #expect(home.occurrences(of: "Image(nsImage:") == 1)
    }
}
