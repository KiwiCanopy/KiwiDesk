import Foundation
import KiwiDeskCore

/// The documentation `kiwidesk mcp` serves (#3213): the
/// user-facing pages of `docs/`, one section per heading, as
/// `scripts/docs-index` wrote them from the tree this binary was
/// built from. Read-only; a section's text is the page's own.
struct DocsIndex: Decodable, Sendable {
    /// One heading and the text under it, up to the next heading.
    struct Section: Decodable, Sendable {
        /// The heading's anchor on its page, as the site links it.
        let anchor: String
        let heading: String
        /// The heading's depth, 1 for the page title.
        let level: Int
        /// The section's text, heading line first, split where a
        /// block ends when it is long.
        let parts: [String]
    }

    struct Page: Decodable, Sendable {
        /// The page's path under `docs/`, without `.md`.
        let page: String
        let title: String
        let description: String
        let sections: [Section]

        /// The sections under `index`: every later one until a
        /// heading at its depth or shallower.
        func subtree(of index: Int) -> Range<Int> {
            let level = sections[index].level
            let rest = sections[(index + 1)...]
            let end = rest.firstIndex { $0.level <= level }
            return index..<(end ?? sections.endIndex)
        }

        /// The sections one level under `index`, at the depth of
        /// the first one nested in it.
        func children(of index: Int) -> [Section] {
            let nested = subtree(of: index).dropFirst()
            guard let first = nested.first else { return [] }
            let depth = sections[first].level
            return nested.map { sections[$0] }.filter { $0.level == depth }
        }
    }

    let pages: [Page]

    /// The resource `scripts/docs-index` writes.
    static let resource = "DocsIndex"

    /// The page whose headings name the commands.
    static let commandPage = "lua-reference"

    /// The index this build ships, or nil where its bundle is
    /// missing or unreadable.
    static let bundled: DocsIndex? = load(from: .kiwiDeskGui)

    static func load(from bundle: Bundle) -> DocsIndex? {
        guard
            let url = bundle.url(
                forResource: resource,
                withExtension: "json"
            ),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(DocsIndex.self, from: data)
    }

    /// A page by its name, with or without `.md`.
    func page(named name: String) -> Page? {
        let bare =
            name.hasSuffix(".md") ? String(name.dropLast(3)) : name
        return pages.first { $0.page == bare }
    }

    /// Where a command is documented: page and anchor.
    struct Link: Sendable, Equatable {
        let page: String
        let anchor: String
    }

    /// Command name → the section whose heading names it, read
    /// off `commandPage`'s headings below the page's groups as
    /// `docs/commands.md`'s links are; the first heading wins.
    var commandLinks: [String: Link] {
        guard let page = page(named: Self.commandPage) else { return [:] }
        var links: [String: Link] = [:]
        for section in page.sections where section.level >= 3 {
            let names = APIReference.commandNames(
                inHeading: section.heading
            )
            for name in names where links[name] == nil {
                links[name] = Link(
                    page: page.page,
                    anchor: section.anchor
                )
            }
        }
        return links
    }

    /// `commandLinks` of the bundled index, read once.
    static let bundledCommandLinks: [String: Link] =
        bundled?.commandLinks ?? [:]
}
