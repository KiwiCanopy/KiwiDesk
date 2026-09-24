import Foundation

/// The update feed read once after an update, for "What's new"
/// (#1542; owner, 2026-09-24: fetch the feed, since the notes are
/// written after the build and never ship inside it).
enum WhatsNewFeed {
    /// One item of the feed, as much as "What's new" needs.
    struct Item: Equatable {
        /// `sparkle:version` — what versions compare on.
        let version: String
        /// `sparkle:shortVersionString`, or the version.
        let shown: String
        let released: Date?
        let notes: String?
    }

    /// The items of a feed document, read with `XMLDocument`, the
    /// parser Sparkle's own appcast reader uses; a malformed
    /// document reads as none.
    static func items(from data: Data) -> [Item] {
        guard
            let document = try? XMLDocument(data: data),
            let nodes = try? document.nodes(forXPath: "//item")
        else { return [] }
        return nodes.compactMap { node in
            guard let item = node as? XMLElement else { return nil }
            func text(_ name: String) -> String? {
                item.children?.first { $0.name == name }?.stringValue?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard let version = text("sparkle:version") else {
                return nil
            }
            return Item(
                version: version,
                shown: text("sparkle:shortVersionString") ?? version,
                released: text("pubDate").flatMap(pubDate),
                notes: text(ReleaseNotes.element)
            )
        }
    }

    /// RFC 822, which is what an RSS `pubDate` is.
    private static func pubDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: text)
    }

    /// One GET; nil when offline or refused — "What's new" then
    /// stays owed until a later launch.
    static func fetch(_ url: URL) async -> [Item]? {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard
            let (data, response) = try? await URLSession.shared.data(
                for: request
            ),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return items(from: data)
    }
}
