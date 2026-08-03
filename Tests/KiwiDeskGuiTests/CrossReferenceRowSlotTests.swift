import Foundation
import Testing

@testable import KiwiDesk

/// A `CrossReferenceRow` renders the destination's name AT the
/// position its prose puts it, which only works while the prose
/// carries `CrossReferenceRow.linkSlot`. Without one the link
/// falls to the end of the sentence — the row's old fixed-order
/// `HStack` shape — and the key has to be authored dangling
/// ("… — edit them in"), which is what forced `ja`, `ko`,
/// `zh-Hans`, `zh-Hant` and `ru` to end their translations on a
/// colon or a bare preposition.
///
/// That fallback is deliberate (a missed call site still renders
/// a followable pointer rather than losing navigation), so it is
/// also silent. This suite is what stops it being reached.
///
/// **The prose is rarely written at the row.** Three of the four
/// call sites pass a computed property or a static helper —
/// `body` cannot hold a `+`-concatenated literal inside a
/// conditional without dying on the CI type-checker (gui.md,
/// SwiftUI traps) — so scanning the call's own argument text
/// would find no `L(` and pass having looked at an identifier.
/// The scan therefore RESOLVES the expression: an inline `L(` is
/// read where it stands, a name is looked up as a `var`/`func`
/// in the same tree and its body read instead.
///
/// Every unresolvable shape fails SHUT, the direction the
/// `SourceScan` walkers are written for: a prose expression this
/// scan cannot attribute reds with a message asking for the
/// shape to be taught, rather than being skipped. Two stated
/// limits, both fail-shut: the body is taken from the first `{`
/// after the declaration, so a default-argument closure in the
/// signature would be read as the body; and a helper that
/// delegates to a SECOND helper is not followed.
@Suite("Cross-reference link position")
struct CrossReferenceRowSlotTests {
    private static let needle = "CrossReferenceRow("
    private static let slot = "CrossReferenceRow.linkSlot"

    private static var guiTree: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDesk")
    }

    /// One rendered cross-reference: where it is written, and the
    /// source its `prose:` argument resolves to.
    struct Site {
        let file: String
        /// The `prose:` argument as written.
        let expression: String
        /// The source that argument resolves to — itself when it
        /// is an inline `L(`, the named declaration's body
        /// otherwise.
        let resolved: String
    }

    private static func sources() throws -> [(String, String)] {
        try SourceScan.swiftSources(under: guiTree)
            .map {
                (
                    $0.lastPathComponent,
                    SourceScan.stripComments(
                        try String(contentsOf: $0, encoding: .utf8)
                    )
                )
            }
    }

    /// Every `CrossReferenceRow(` application in the GUI tree,
    /// with its `prose:` argument resolved.
    private static func sites() throws -> [Site] {
        let files = try sources()
        var out: [Site] = []
        for (name, source) in files {
            for arguments in calls(needle, in: source) {
                let expression = try #require(
                    argument("prose", in: arguments),
                    "\(name): CrossReferenceRow with no prose:"
                )
                out.append(
                    Site(
                        file: name,
                        expression: expression,
                        resolved: try resolve(
                            expression,
                            in: files,
                            from: name
                        )
                    )
                )
            }
        }
        return out
    }

    /// The prose either IS an `L(` call or NAMES one. A name is
    /// resolved to the body of its declaration; anything else is
    /// a shape this scan cannot attribute, and reds.
    private static func resolve(
        _ expression: String,
        in files: [(String, String)],
        from file: String
    ) throws -> String {
        if expression.contains("L(") { return expression }
        let head =
            expression.split(separator: "(").first.map(String.init)
            ?? expression
        let name = try #require(
            head.split(separator: ".").last.map(String.init)?
                .trimmingCharacters(in: .whitespaces),
            "\(file): unreadable prose expression \(expression)"
        )
        for keyword in ["var ", "func "] {
            for (_, source) in files {
                if let body = declaration(
                    keyword + name,
                    in: source
                ) {
                    return body
                }
            }
        }
        Issue.record(
            """
            \(file): prose \(expression) resolves to no var or \
            func named \(name) — teach this scan the shape \
            rather than leaving the call site unwatched
            """
        )
        return ""
    }

    /// The brace body of the first declaration matching `header`.
    private static func declaration(
        _ header: String,
        in source: String
    ) -> String? {
        let text = Array(source)
        guard let start = range(of: header, in: text) else {
            return nil
        }
        var brace = start
        while brace < text.count, text[brace] != "{" { brace += 1 }
        guard brace < text.count else { return nil }
        var cursor = brace
        return SourceScan.balanced(
            text,
            from: &cursor,
            open: "{",
            close: "}"
        )
    }

    /// Each `needle` application's balanced argument list.
    private static func calls(
        _ needle: String,
        in source: String
    ) -> [String] {
        let text = Array(source)
        var out: [String] = []
        var i = 0
        while let hit = range(of: needle, in: text, from: i) {
            var cursor = hit + needle.count - 1
            guard
                let arguments = SourceScan.balanced(
                    text,
                    from: &cursor,
                    open: "(",
                    close: ")"
                )
            else {
                i = hit + needle.count
                continue
            }
            out.append(arguments)
            i = cursor
        }
        return out
    }

    /// The argument labelled `label`, split at top-level commas.
    private static func argument(
        _ label: String,
        in arguments: String
    ) -> String? {
        var depth = 0
        var inString = false
        var previous: Character?
        var parts: [String] = []
        var current = ""
        for character in arguments {
            if inString {
                current.append(character)
                if character == "\"", previous != "\\" {
                    inString = false
                }
                previous = character
                continue
            }
            switch character {
            case "\"": inString = true
            case "(", "[", "{": depth += 1
            case ")", "]", "}": depth -= 1
            case "," where depth == 0:
                parts.append(current)
                current = ""
                previous = character
                continue
            default: break
            }
            current.append(character)
            previous = character
        }
        parts.append(current)
        let prefix = "\(label):"
        return
            parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.hasPrefix(prefix) }
            .map {
                String($0.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
    }

    private static func range(
        of needle: String,
        in text: [Character],
        from start: Int = 0
    ) -> Int? {
        let wanted = Array(needle)
        var i = max(0, start)
        while i + wanted.count <= text.count {
            if Array(text[i..<(i + wanted.count)]) == wanted {
                return i
            }
            i += 1
        }
        return nil
    }

    /// The walk finds the call sites at all, and finds ALL of
    /// them. Both halves matter: an enumerator over a missing
    /// directory yields nothing and every assertion below then
    /// passes over an empty set, and a walker that resolves only
    /// the inline shape would silently drop the three call sites
    /// whose prose is a named helper — the majority.
    ///
    /// The expected count is DERIVED from the same tree rather
    /// than written here: a hand-listed number would agree with
    /// this file and with nothing else.
    @Test func everyRowIsDiscovered() throws {
        let sites = try Self.sites()
        let written = try Self.sources()
            .map { $0.1.occurrences(of: Self.needle) }
            .reduce(0, +)
        #expect(written > 0, "no CrossReferenceRow call sites")
        #expect(sites.count == written)
        // The named-helper shape is the one a naive scan misses,
        // so pin that the resolver is still exercising it.
        #expect(
            sites.contains { !$0.expression.contains("L(") }
        )
        // A resolution that returned nothing would satisfy
        // `contains` below only by failing it, but an empty body
        // means the lookup found a declaration and read no
        // source — worth separating from a real violation.
        for site in sites {
            #expect(
                !site.resolved.isEmpty,
                "\(site.file): \(site.expression) resolved empty"
            )
        }
    }

    @Test func everyProseCarriesTheLinkSlot() throws {
        for site in try Self.sites() {
            #expect(
                site.resolved.contains(Self.slot),
                """
                \(site.file): prose \(site.expression) never \
                passes \(Self.slot), so its link falls to the \
                end of the sentence and every locale has to \
                author the key dangling
                """
            )
        }
    }
}
