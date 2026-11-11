import Foundation
import KiwiDeskCore

/// Ranked search over the bundled docs (#3213): plain term
/// matching, a heading match outweighing body matches and a rare
/// term a common one, so a command or setting name finds its own
/// section first.
extension DocsIndex {
    /// One ranked part of a section.
    struct Hit: Sendable {
        let page: String
        let anchor: String
        let heading: String
        /// 1-based part of the section, of `parts`.
        let part: Int
        let parts: Int
        let snippet: String
    }

    /// The sections a search may read: a page, or one section of
    /// it with everything nested under it.
    struct Scope: Sendable {
        let page: Page
        let range: Range<Int>
    }

    /// Why a `section` argument names nothing.
    enum ScopeRefusal: Error, Equatable {
        case noPage(String)
        case noAnchor(page: String, anchor: String)
    }

    /// The scope `section` names: `page` or `page#anchor`.
    func scope(_ section: String) -> Result<Scope, ScopeRefusal> {
        let pieces = section.split(
            separator: "#",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let name = String(pieces.first ?? "")
        guard let page = page(named: name) else {
            return .failure(.noPage(name))
        }
        guard pieces.count == 2, !pieces[1].isEmpty else {
            return .success(
                Scope(page: page, range: page.sections.indices)
            )
        }
        let anchor = String(pieces[1])
        guard
            let index = page.sections.firstIndex(where: {
                $0.anchor == anchor
            })
        else {
            return .failure(.noAnchor(page: page.page, anchor: anchor))
        }
        return .success(Scope(page: page, range: page.subtree(of: index)))
    }

    /// Words that carry no topic in a plain request.
    private static let stopWords: Set<String> = [
        "a", "an", "and", "can", "do", "for", "how", "i", "in", "is",
        "it", "me", "my", "of", "on", "or", "the", "to", "what", "with",
    ]

    /// The query's terms: lowercased, split on anything but
    /// letters, digits, `_` and `.`, a plural's `s` dropped so
    /// "borders" finds "border".
    static func terms(of query: String) -> [String] {
        var seen: Set<String> = []
        let words = query.lowercased().split { character in
            !(character.isLetter || character.isNumber
                || character == "_" || character == ".")
        }
        return words.compactMap { word -> String? in
            var term = String(word)
            while term.hasSuffix(".") { term.removeLast() }
            if term.count > 3, term.hasSuffix("s"), !term.hasSuffix("ss") {
                term.removeLast()
            }
            guard !term.isEmpty, !stopWords.contains(term),
                seen.insert(term).inserted
            else { return nil }
            return term
        }
    }

    /// What one term is worth where it is found: in the heading
    /// as a command's own name, as a word of the heading, and per
    /// mention in the text, up to `bodyCeiling` mentions.
    private static let nameWeight = 6.0
    private static let headingWeight = 4.0
    private static let bodyWeight = 0.4
    private static let bodyCeiling = 5

    /// The words of a heading: split on anything but letters and
    /// digits, a plural's `s` dropped as `terms(of:)` drops it.
    private static func words(ofHeading heading: String) -> Set<String> {
        Set(
            heading.split { !($0.isLetter || $0.isNumber) }.map { word in
                var word = String(word)
                if word.count > 3, word.hasSuffix("s"),
                    !word.hasSuffix("ss")
                {
                    word.removeLast()
                }
                return word
            }
        )
    }

    /// One term's worth in one part, before rarity is weighed;
    /// `heading` is nil for a part past its section's first.
    private static func worth(
        of term: String,
        in body: String,
        heading: String?,
        names: Set<String>,
        words: Set<String>
    ) -> Double {
        let mentions = min(bodyCeiling, count(of: term, in: body))
        var worth = Double(mentions) * bodyWeight
        guard let heading else { return worth }
        if names.contains(term) { worth += nameWeight }
        let compound = term.contains { $0 == "_" || $0 == "." }
        if words.contains(term) || (compound && heading.contains(term)) {
            worth += headingWeight
        }
        return worth
    }

    /// The best `limit` parts for `query`, by score, then in page
    /// order. A term found in few parts counts for more than one
    /// found in many, so "border" outweighs "window"; a heading
    /// counts for its section's first part alone.
    func search(_ query: String, in scope: Scope?, limit: Int) -> [Hit] {
        let terms = Self.terms(of: query)
        guard !terms.isEmpty else { return [] }
        struct Candidate {
            let page: Page
            let section: Section
            let part: Int
            /// Per term, its worth before rarity is weighed.
            let worth: [Double]
        }
        var candidates: [Candidate] = []
        var found = [Int](repeating: 0, count: terms.count)
        var total = 0
        let scopes =
            scope.map { [$0] }
            ?? pages.map { Scope(page: $0, range: $0.sections.indices) }
        for scope in scopes {
            for index in scope.range {
                let section = scope.page.sections[index]
                let heading = section.heading.lowercased()
                let names = Set(
                    APIReference.commandNames(inHeading: heading)
                )
                let words = Self.words(ofHeading: heading)
                for (number, text) in section.parts.enumerated() {
                    total += 1
                    let body = text.lowercased()
                    let worth = terms.map { term in
                        Self.worth(
                            of: term,
                            in: body,
                            heading: number == 0 ? heading : nil,
                            names: names,
                            words: words
                        )
                    }
                    guard worth.contains(where: { $0 > 0 }) else { continue }
                    for (term, value) in worth.enumerated() where value > 0 {
                        found[term] += 1
                    }
                    candidates.append(
                        Candidate(
                            page: scope.page,
                            section: section,
                            part: number,
                            worth: worth
                        )
                    )
                }
            }
        }
        let rarity: [Double] = found.map { count in
            let share = Double(total) / Double(1 + count)
            return log(1 + share)
        }
        var scored: [(score: Double, order: Int, candidate: Candidate)] = []
        for (order, candidate) in candidates.enumerated() {
            var score = 0.0
            for (term, worth) in candidate.worth.enumerated() {
                score += worth * rarity[term]
            }
            scored.append((score, order, candidate))
        }
        scored.sort { left, right in
            if left.score != right.score { return left.score > right.score }
            return left.order < right.order
        }
        return scored.prefix(limit).map { ranked in
            let candidate = ranked.candidate
            return Hit(
                page: candidate.page.page,
                anchor: candidate.section.anchor,
                heading: candidate.section.heading,
                part: candidate.part + 1,
                parts: candidate.section.parts.count,
                snippet: Self.snippet(
                    of: candidate.section.parts[candidate.part],
                    around: terms
                )
            )
        }
    }

    private static func count(of term: String, in text: String) -> Int {
        text.components(separatedBy: term).count - 1
    }

    /// The characters a snippet shows before and after its term.
    private static let snippetLead = 80
    private static let snippetTail = 200

    /// A stretch of `text` around the first term its body holds,
    /// else the body's opening; whitespace runs become one space.
    static func snippet(of text: String, around terms: [String]) -> String {
        let body =
            text.split(
                separator: "\n",
                maxSplits: 1,
                omittingEmptySubsequences: false
            ).dropFirst().first.map(String.init) ?? ""
        let lowered = body.lowercased()
        let found = terms.compactMap { lowered.range(of: $0)?.lowerBound }
            .min()
        let offset =
            found.map { lowered.distance(from: lowered.startIndex, to: $0) }
            ?? 0
        let characters = Array(body)
        // Lowercasing may change a string's length; stay in range.
        let centre = min(offset, characters.count)
        let start = max(0, centre - snippetLead)
        let end = min(characters.count, centre + snippetTail)
        let words = String(characters[start..<end])
            .split(whereSeparator: \.isWhitespace)
        var out = words.joined(separator: " ")
        if start > 0 { out = "…" + out }
        if end < characters.count { out += "…" }
        return out
    }
}
