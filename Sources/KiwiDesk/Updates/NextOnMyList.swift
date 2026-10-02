import Foundation

/// The "Next on my list" card in the What's new window (#1813
/// ruling): ROADMAP.md's section of that name, which the site
/// build serves as `fileName` beside the update feed.
/// `site/src/lib/roadmap.ts` is the one parser of the Markdown;
/// this reads only its JSON.
struct NextOnMyList: Codable, Equatable {
    /// The file beside the appcast. Permanent from the first build
    /// that reads it, like `SUFeedURL`; `check-site-tokens.py`
    /// holds the site to it and to `knownFormats`.
    static let fileName = "roadmap.json"

    /// The `FORMAT` values this window reads.
    static let knownFormats: Set<Int> = [1]

    /// A list dated longer ago than this is hidden, so one that
    /// stopped being kept disappears instead of promising.
    static let maxAge: TimeInterval = 60 * 86_400

    /// Slack for a date written east of UTC.
    private static let aheadSlack: TimeInterval = 86_400

    /// Midnight UTC of the section's "As of" day.
    let asOf: Date
    let items: [String]

    private struct Document: Decodable {
        let format: Int
        let asOf: String?
        let items: [String]?

        enum CodingKeys: String, CodingKey {
            case format, items
            case asOf = "as_of"
        }
    }

    /// Nil for an unknown format, a document that does not decode,
    /// or a section with no date or no items. Unknown keys are
    /// ignored, so the document can grow without a format bump.
    static func decode(_ data: Data) -> NextOnMyList? {
        guard
            let document = try? JSONDecoder().decode(
                Document.self,
                from: data
            ),
            knownFormats.contains(document.format),
            let day = document.asOf,
            let asOf = Self.day(day),
            let items = document.items, !items.isEmpty
        else { return nil }
        return NextOnMyList(asOf: asOf, items: items)
    }

    private static func day(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: text)
    }

    /// Self while the card may show at `now`, else nil.
    func current(at now: Date) -> NextOnMyList? {
        let age = now.timeIntervalSince(asOf)
        guard age <= Self.maxAge, age >= -Self.aheadSlack else {
            return nil
        }
        return self
    }

    /// `…/appcast.xml` → `…/roadmap.json`.
    static func url(besideFeed feed: URL) -> URL {
        feed.deletingLastPathComponent()
            .appendingPathComponent(fileName)
    }

    /// One GET; nil when offline, refused or unreadable, which
    /// only leaves the card out. Off the main actor: it decodes
    /// the list.
    @concurrent static func fetch(
        besideFeed feed: URL
    ) async -> NextOnMyList? {
        var request = URLRequest(url: url(besideFeed: feed))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        // What's new waits on this before it opens.
        request.timeoutInterval = 5
        guard
            let (data, response) = try? await URLSession.shared.data(
                for: request
            ),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return decode(data)
    }
}
