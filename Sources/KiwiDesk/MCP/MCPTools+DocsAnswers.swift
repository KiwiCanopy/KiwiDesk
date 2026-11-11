import Foundation
import KiwiDeskCore

/// What the docs tools answer with (#3213), and the fields that
/// link a command to its documentation.
extension MCPTools {
    /// One section's part as `docs_get` returns it: the text
    /// first, then what else there is to read.
    static func docsSection(
        _ page: DocsIndex.Page,
        at index: Int,
        part: Int
    ) -> JSONValue {
        let section = page.sections[index]
        let text = section.parts[part - 1]
        let children = page.children(of: index)
        var notes: [String] = []
        if section.parts.count > 1 {
            notes.append(
                "Part \(part) of \(section.parts.count); pass part "
                    + "for the others."
            )
        }
        if !children.isEmpty {
            let list = children.map { "#\($0.anchor)" }
                .joined(separator: ", ")
            notes.append("Sections under this one: \(list)")
        }
        let trailer =
            notes.isEmpty ? "" : "\n\n" + notes.joined(separator: "\n")
        return result(
            text + trailer,
            structured: .object([
                "page": .string(page.page),
                "anchor": .string(section.anchor),
                "heading": .string(section.heading),
                "part": .number(Double(part)),
                "parts": .number(Double(section.parts.count)),
                "text": .string(text),
                "subsections": .array(children.map(sectionRow)),
                "version": .string(KiwiDeskVersion.displayString),
            ])
        )
    }

    /// The page and section index: every page with its top
    /// sections, or one scope's sections in full.
    static func docsListing(
        _ index: DocsIndex,
        scope: DocsIndex.Scope?
    ) -> JSONValue {
        var lines = ["KiwiDesk \(KiwiDeskVersion.displayString)"]
        var rows: [JSONValue] = []
        let scopes =
            scope.map { [$0] }
            ?? index.pages.map {
                DocsIndex.Scope(page: $0, range: $0.sections.indices)
            }
        for listed in scopes {
            let page = listed.page
            let sections = listed.range.map { page.sections[$0] }
                .filter { scope != nil || $0.level == 2 }
            lines.append("\(page.page) — \(page.title): \(page.description)")
            for section in sections {
                let indent = String(repeating: "  ", count: section.level - 1)
                lines.append("\(indent)#\(section.anchor) \(section.heading)")
            }
            rows.append(
                .object([
                    "page": .string(page.page),
                    "title": .string(page.title),
                    "description": .string(page.description),
                    "sections": .array(sections.map(sectionRow)),
                ])
            )
        }
        return result(
            lines.joined(separator: "\n"),
            structured: .object([
                "version": .string(KiwiDeskVersion.displayString),
                "pages": .array(rows),
            ])
        )
    }

    private static func sectionRow(
        _ section: DocsIndex.Section
    ) -> JSONValue {
        .object([
            "anchor": .string(section.anchor),
            "heading": .string(section.heading),
            "level": .number(Double(section.level)),
        ])
    }

    /// What to say for a page or anchor the index does not hold.
    static func text(
        of refusal: DocsIndex.ScopeRefusal,
        in index: DocsIndex
    ) -> String {
        switch refusal {
        case .noPage(let name):
            let pages = index.pages.map(\.page).joined(separator: ", ")
            return "no page \"\(name)\"; the pages are \(pages)"
        case .noAnchor(let page, let anchor):
            return "no section #\(anchor) in \(page); \(docsSearch) with "
                + "an empty query and section \"\(page)\" lists them"
        }
    }

    /// The fields `help` and `list_commands` add to a command:
    /// `docs`, where the bundled docs describe it, and `lua`, the
    /// call a config writes. Either is left out where there is
    /// none.
    static func docsFields(
        for entry: APIEntry,
        links: [String: DocsIndex.Link] = DocsIndex.bundledCommandLinks
    ) -> [String: JSONValue] {
        var fields: [String: JSONValue] = [:]
        if let link = links[entry.qualifiedName] {
            fields["docs"] = .object([
                "page": .string(link.page),
                "anchor": .string(link.anchor),
            ])
        }
        if let call = APIReference.luaCall(for: entry) {
            fields["lua"] = .string(call)
        }
        return fields
    }
}
