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
            "Searches the documentation this build ships (Lua "
                + "reference, user guide, CLI, limitations, recipes) "
                + "and returns ranked sections: page, anchor, heading "
                + "and a snippet. Read one with \(docsGet). An empty "
                + "query lists the pages, their sections and the app "
                + "version.",
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

    /// `docs_search`: an empty query lists, any other ranks.
    func searchDocs(_ arguments: [String: JSONValue]) -> JSONValue {
        guard let index = docs else { return Self.failure(Self.docsMissing) }
        var scope: DocsIndex.Scope?
        if let section = arguments["section"]?.stringValue, !section.isEmpty {
            switch index.scope(section) {
            case .success(let found): scope = found
            case .failure(let refusal):
                return Self.failure(Self.text(of: refusal, in: index))
            }
        }
        var limit = Self.docsDefaultLimit
        if let given = arguments["limit"], given != .null {
            guard case .number = given, let count = given.intValue,
                (1...Self.docsLimitCeiling).contains(count)
            else {
                return Self.failure(
                    "limit expects 1 to \(Self.docsLimitCeiling)"
                )
            }
            limit = count
        }
        let query = arguments["query"]?.stringValue ?? ""
        guard !DocsIndex.terms(of: query).isEmpty else {
            return Self.docsListing(index, scope: scope)
        }
        let hits = index.search(query, in: scope, limit: limit)
        guard !hits.isEmpty else {
            return Self.result(
                "No section matches \"\(query)\".",
                structured: .object(["results": .array([])])
            )
        }
        let lines = hits.map { hit in
            let part = hit.parts > 1 ? " (part \(hit.part))" : ""
            return "\(hit.page)#\(hit.anchor)\(part) — \(hit.heading)\n"
                + "  \(hit.snippet)"
        }
        let rows = hits.map { hit -> JSONValue in
            .object([
                "page": .string(hit.page),
                "anchor": .string(hit.anchor),
                "heading": .string(hit.heading),
                "part": .number(Double(hit.part)),
                "parts": .number(Double(hit.parts)),
                "snippet": .string(hit.snippet),
            ])
        }
        return Self.result(
            lines.joined(separator: "\n"),
            structured: .object(["results": .array(rows)])
        )
    }

    /// `docs_get`: one part of one section, word for word.
    func getDocs(_ arguments: [String: JSONValue]) -> JSONValue {
        guard let index = docs else { return Self.failure(Self.docsMissing) }
        guard let name = arguments["page"]?.stringValue, !name.isEmpty
        else { return Self.failure("\(Self.docsGet) needs a page") }
        guard let page = index.page(named: name) else {
            return Self.failure(Self.text(of: .noPage(name), in: index))
        }
        var at = 0
        if let anchor = arguments["anchor"]?.stringValue, !anchor.isEmpty {
            guard
                let found = page.sections.firstIndex(where: {
                    $0.anchor == anchor
                })
            else {
                return Self.failure(
                    Self.text(
                        of: .noAnchor(page: page.page, anchor: anchor),
                        in: index
                    )
                )
            }
            at = found
        }
        let section = page.sections[at]
        var part = 1
        if let given = arguments["part"], given != .null {
            guard case .number = given, let number = given.intValue,
                (1...section.parts.count).contains(number)
            else {
                return Self.failure(
                    "part expects 1 to \(section.parts.count)"
                )
            }
            part = number
        }
        return Self.docsSection(page, at: at, part: part)
    }
}
