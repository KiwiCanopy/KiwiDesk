import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// What's new's release menu (#2308): which releases it lists,
/// which one it opens on, and the notes each one shows.
@MainActor
@Suite("What's new releases (#2308)")
struct WhatsNewReleasesTests {
    private static func item(
        _ version: String,
        readable: Bool = true,
        released: Date? = nil
    ) -> WhatsNewFeed.Item {
        .init(
            version: version,
            shown: version,
            released: released,
            notes: readable ? WhatsNewFixture.notes(version) : nil
        )
    }

    @Test("Lists every readable release up to the running one, newest first")
    func listsReadableUpToCurrent() throws {
        let releases = try #require(
            WhatsNewReleases(
                items: [
                    Self.item("2.3.0"), Self.item("3.2.0"),
                    Self.item("3.1.0"), Self.item("1.4.0", readable: false),
                    Self.item("3.0.0"),
                ],
                current: "3.1.0"
            )
        )
        #expect(
            releases.options == [
                .release("3.1.0"), .release("3.0.0"), .release("2.3.0"),
            ]
        )
    }

    @Test("No list when the running version's own notes do not read")
    func nilWithoutCurrentNotes() {
        #expect(
            WhatsNewReleases(
                items: [
                    Self.item("3.1.0", readable: false), Self.item("3.0.0"),
                ],
                current: "3.1.0"
            ) == nil
        )
        #expect(
            WhatsNewReleases(items: [Self.item("3.0.0")], current: "3.1.0")
                == nil
        )
    }

    @Test("The merged range is listed only when it spans two releases")
    func sinceNeedsTwoReleases() throws {
        let items = [
            Self.item("3.1.0"), Self.item("3.0.0"), Self.item("2.3.0"),
        ]
        let spanning = try #require(
            WhatsNewReleases(items: items, current: "3.1.0", since: "2.3.0")
        )
        #expect(spanning.options.first == .since("2.3.0"))
        let single = try #require(
            WhatsNewReleases(items: items, current: "3.1.0", since: "3.0.0")
        )
        #expect(single.since == nil)
        #expect(single.options.first == .release("3.1.0"))
    }

    /// The range is the owed digest's own: a skipped release whose
    /// notes do not read still counts toward it and keeps its
    /// link, though it never lists alone.
    @Test("An unreadable skipped release keeps the range and its link")
    func unreadableKeepsTheRange() throws {
        let releases = try #require(
            WhatsNewReleases(
                items: [
                    Self.item("3.1.0"), Self.item("3.0.0", readable: false),
                    Self.item("2.3.0"),
                ],
                current: "3.1.0",
                since: "2.3.0"
            )
        )
        #expect(
            releases.options == [
                .since("2.3.0"), .release("3.1.0"),
                .release("2.3.0"),
            ]
        )
        let range = try #require(releases.offer(for: .since("2.3.0")))
        #expect(range.digest?.unreadable == ["3.0.0"])
    }

    @Test("Owed notes open on the range; every other open on this version")
    func openingRule() throws {
        let items = [
            Self.item("3.1.0"), Self.item("3.0.0"), Self.item("2.3.0"),
        ]
        let releases = try #require(
            WhatsNewReleases(items: items, current: "3.1.0", since: "2.3.0")
        )
        #expect(releases.opening(owed: true) == .since("2.3.0"))
        #expect(releases.opening(owed: false) == .release("3.1.0"))
        let plain = try #require(
            WhatsNewReleases(items: items, current: "3.1.0")
        )
        #expect(plain.opening(owed: true) == .release("3.1.0"))
    }

    @Test("One release shows itself alone; the range merges, newest first")
    func offersPerOption() throws {
        let items = [
            Self.item("3.1.0"), Self.item("3.0.0"), Self.item("2.3.0"),
        ]
        let releases = try #require(
            WhatsNewReleases(items: items, current: "3.1.0", since: "2.3.0")
        )
        let older = try #require(releases.offer(for: .release("3.0.0")))
        #expect(older.digest?.versions == ["3.0.0"])
        #expect(older.digest?.spansVersions == false)
        #expect(older.version == "3.0.0")
        let range = try #require(releases.offer(for: .since("2.3.0")))
        #expect(range.digest?.versions == ["3.1.0", "3.0.0"])
        #expect(range.version == "3.1.0")
    }

    @Test("Entries carry their date; the running one is marked")
    func titles() throws {
        LocalizationManager.shared.select("en")
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let releases = try #require(
            WhatsNewReleases(
                items: [
                    Self.item("3.1.0", released: date), Self.item("3.0.0"),
                    Self.item("2.3.0"),
                ],
                current: "3.1.0",
                since: "2.3.0"
            )
        )
        let current = ReleasePicker.title(.release("3.1.0"), in: releases)
        #expect(current.hasPrefix("3.1.0 · "))
        #expect(current.hasSuffix(" (this version)"))
        #expect(
            ReleasePicker.title(.release("3.0.0"), in: releases) == "3.0.0"
        )
        #expect(
            ReleasePicker.title(.since("2.3.0"), in: releases) == "Since 2.3.0"
        )
    }
}
