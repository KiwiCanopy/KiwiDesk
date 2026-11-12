import Foundation
import KiwiDeskCore

/// The docs tools (#3213): search and read the documentation this
/// build ships, without the app and without the network.
extension MCPTools {
    static let docsSearch = "docs_search"
    static let docsGet = "docs_get"

    /// How many hits a search returns: by default, and at most.
    static let docsDefaultLimit = 5
    static let docsLimitCeiling = 20

    static let docsSearchTool = Tool(
        name: docsSearch,
        definition: MCPToolSchema.tool(
            docsSearch,
            title: "Search the KiwiDesk docs",
            "Searches the documentation this build ships and returns "
                + "ranked sections: page, anchor, heading and a snippet. "
                + "Read one with \(docsGet). An empty query lists the "
                + "pages, their sections and the app version.",
            properties: [
                "query": MCPToolSchema.string(
                    "Words or a command name; empty lists the pages."
                ),
                "section": MCPToolSchema.string(
                    "Narrows to a page, or to page#anchor and the "
                        + "sections under it."
                ),
                "limit": MCPToolSchema.integer(
                    "How many sections to return, 1 to "
                        + "\(docsLimitCeiling); \(docsDefaultLimit) "
                        + "when omitted."
                ),
            ],
            readOnly: true
        ),
        handle: { tools, arguments in tools.searchDocs(arguments) }
    )

    static let docsGetTool = Tool(
        name: docsGet,
        definition: MCPToolSchema.tool(
            docsGet,
            title: "Read a KiwiDesk docs section",
            "Returns one documentation section's exact text, by the "
                + "page and anchor \(docsSearch), \(help) or "
                + "\(listCommands) gave. Quote it when telling the "
                + "user what a setting or command does.",
            properties: [
                "page": MCPToolSchema.string("The page's name."),
                "anchor": MCPToolSchema.string(
                    "The section's anchor; the page's opening when "
                        + "omitted."
                ),
                "part": MCPToolSchema.integer(
                    "Which part of a long section, from 1."
                ),
            ],
            required: ["page"],
            readOnly: true
        ),
        handle: { tools, arguments in tools.getDocs(arguments) }
    )

    static let docsMissing =
        "This build carries no documentation index."

    /// A text argument: nil where absent or null, refused where it
    /// is anything but text.
    private static func text(
        _ key: String,
        in arguments: [String: JSONValue]
    ) throws -> String? {
        switch arguments[key] {
        case nil, .null?: return nil
        case .string(let text)?: return text
        default: throw MCPToolRefusal("\(key) expects text")
        }
    }

    /// A whole-number argument inside `range`: nil where absent or
    /// null, refused where it is anything else.
    private static func whole(
        _ key: String,
        in arguments: [String: JSONValue],
        within range: ClosedRange<Int>
    ) throws -> Int? {
        switch arguments[key] {
        case nil, .null?:
            return nil
        case .number(let number)?:
            if number == number.rounded(), let whole = number.finiteInt,
                range.contains(whole)
            {
                return whole
            }
            fallthrough
        default:
            throw MCPToolRefusal(
                "\(key) expects \(range.lowerBound) to \(range.upperBound)"
            )
        }
    }

    /// Runs a docs tool's body, answering a refusal as a tool error.
    private func answeringDocs(
        _ body: (DocsIndex) throws -> JSONValue
    ) -> JSONValue {
        guard let index = docs else { return Self.failure(Self.docsMissing) }
        do {
            return try body(index)
        } catch let refusal as MCPToolRefusal {
            return Self.failure(refusal.reason)
        } catch {
            return Self.failure("\(error)")
        }
    }

    /// `docs_search`: an empty query lists, any other ranks.
    func searchDocs(_ arguments: [String: JSONValue]) -> JSONValue {
        answeringDocs { index in
            var scope: DocsIndex.Scope?
            if let section = try Self.text("section", in: arguments),
                !section.isEmpty
            {
                switch index.scope(section) {
                case .success(let found): scope = found
                case .failure(let refusal):
                    throw MCPToolRefusal(Self.text(of: refusal, in: index))
                }
            }
            let limit =
                try Self.whole(
                    "limit",
                    in: arguments,
                    within: 1...Self.docsLimitCeiling
                ) ?? Self.docsDefaultLimit
            let query = try Self.text("query", in: arguments) ?? ""
            guard !DocsIndex.terms(of: query).isEmpty else {
                return Self.docsListing(index, scope: scope)
            }
            return Self.docsHits(
                index.search(query, in: scope, limit: limit),
                for: query
            )
        }
    }

    /// `docs_get`: one part of one section, word for word.
    func getDocs(_ arguments: [String: JSONValue]) -> JSONValue {
        answeringDocs { index in
            guard let name = try Self.text("page", in: arguments),
                !name.isEmpty
            else { throw MCPToolRefusal("\(Self.docsGet) needs a page") }
            guard let page = index.page(named: name) else {
                throw MCPToolRefusal(Self.text(of: .noPage(name), in: index))
            }
            var at = 0
            if let anchor = try Self.text("anchor", in: arguments),
                !anchor.isEmpty
            {
                guard
                    let found = page.sections.firstIndex(where: {
                        $0.anchor == anchor
                    })
                else {
                    throw MCPToolRefusal(
                        Self.text(
                            of: .noAnchor(page: page.page, anchor: anchor),
                            in: index
                        )
                    )
                }
                at = found
            }
            let part =
                try Self.whole(
                    "part",
                    in: arguments,
                    within: 1...page.sections[at].parts.count
                ) ?? 1
            return Self.docsSection(page, at: at, part: part)
        }
    }
}
