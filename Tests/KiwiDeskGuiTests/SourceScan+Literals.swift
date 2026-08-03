import Foundation

/// Quote-aware source scrubbing, and the member a source offset
/// sits in.
///
/// These live in the `SourceScan` family rather than beside their
/// caller for the reason that family exists: a second copy of a
/// walker that drifts silently changes what a guard observes.
/// `blankingCommentsAndLiterals` in particular is a HARDENED
/// `stripComments` — the two must not be chained, and a divergent
/// copy of it would reintroduce exactly the fail-open the comment
/// on it describes.
extension SourceScan {
    /// Blanks comments AND string literals in one pass, keeping
    /// every character position so offsets stay usable.
    ///
    /// Neither half may be delegated to `stripComments`, which
    /// cuts at the first `//` with no idea whether it sits inside
    /// a literal. Chaining the two fails OPEN, and guard-prover
    /// proved it against the App Rules row: a
    /// `"https://kiwidesk.app"` leaves an unterminated quote on
    /// its line, after which a literal-blanker erases everything
    /// to the next `"` — swallowing a real `HStack(spacing: 6)`
    /// and leaving the suite green.
    ///
    /// The literal half matters on its own: a needle must not be
    /// satisfiable by a string that merely spells it, which is
    /// how an accessibility label once stood in for a layout.
    static func blankingCommentsAndLiterals(
        _ source: String
    ) -> String {
        var out = ""
        var inString = false
        var escaped = false
        var index = source.startIndex
        while index < source.endIndex {
            let character = source[index]
            if escaped {
                escaped = false
                out.append(" ")
                index = source.index(after: index)
                continue
            }
            if inString, character == "\\" {
                escaped = true
                out.append(" ")
                index = source.index(after: index)
                continue
            }
            if character == "\"" {
                inString.toggle()
                out.append(character)
                index = source.index(after: index)
                continue
            }
            // A comment only starts outside a literal — the whole
            // point of doing both in one pass.
            if !inString, character == "/",
                source.index(after: index) < source.endIndex,
                source[source.index(after: index)] == "/"
            {
                while index < source.endIndex, source[index] != "\n" {
                    out.append(" ")
                    index = source.index(after: index)
                }
                continue
            }
            out.append(inString ? " " : character)
            index = source.index(after: index)
        }
        return out
    }

    /// Every member kind that can hold a view.
    ///
    /// An UNRECOGNISED kind is the dangerous case for any caller
    /// keying an allow-list on a member name: the name would stay
    /// whatever the last parsed member was, so a `subscript` or
    /// `init` written after an exempt member inherits its
    /// exemption. guard-prover shipped that mutation past a cut
    /// listing only `var` and `func`. A kind still missing
    /// degrades the same way — add one rather than assuming the
    /// shape is unreachable.
    static let memberKeywords = [
        "var ", "func ", "let ", "subscript", "init",
        "struct ", "enum ", "extension ",
    ]

    /// The member a source offset sits in — the nearest preceding
    /// declaration name, or the bare keyword for an unnamed one
    /// (`subscript(`, `init(`), which must RESET rather than fall
    /// through to the previous member.
    static func enclosingMember(
        of source: String,
        at offset: String.Index
    ) -> String {
        var name = "<file scope>"
        var cursor = source.startIndex
        while cursor < offset {
            let lineEnd =
                source[cursor...].firstIndex(of: "\n")
                ?? source.endIndex
            let line = source[cursor..<lineEnd]
            for keyword in memberKeywords {
                guard let range = line.range(of: keyword) else {
                    continue
                }
                let rest = line[range.upperBound...]
                let identifier = rest.prefix {
                    $0.isLetter || $0.isNumber || $0 == "_"
                }
                name =
                    identifier.isEmpty
                    ? keyword.trimmingCharacters(in: .whitespaces)
                    : String(identifier)
            }
            cursor =
                lineEnd < source.endIndex
                ? source.index(after: lineEnd) : source.endIndex
        }
        return name
    }
}
