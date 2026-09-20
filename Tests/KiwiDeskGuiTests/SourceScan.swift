import Foundation

/// Stateless primitives shared by the source-scanning parity
/// guards: the catalog guards (`SettingsCatalogSiteTests`,
/// `SettingsCatalogArgumentTests`,
/// `SettingsAnchorPrimitiveTests`), `DiscardGateParityTests`,
/// `GreyOutParityTests`, and the two bounds-routing guards
/// (`VisibleBoundsRoutingTests`, `LayoutBoundsRoutingTests`)
/// and `BarMotionSeamTests` — which scan
/// `Sources/KiwiDeskCore`, not the GUI tree, and live here only
/// because this helper does.
///
/// Ratified as a third shared test primitive under AGENTS.md §5
/// ("Split test suites early") and `.claude/rules/tests.md`, on
/// their own bar — **drift risk, not copy count**. `balanced` and
/// `swiftSources` were byte-identical in both suites, and the
/// named harm is concrete: harden the walker in one copy and not
/// the other (raw strings, multiline literals, interpolation) and
/// the *over*-matching copy silently swallows call sites its
/// guard was meant to catch. A guard that passes for the wrong
/// reason is the exact failure both suites exist to prevent.
/// Stateless, no setup/teardown, no assertions of its own —
/// the same shape as `ReflectionParity` and `ScriptFixture`.
enum SourceScan {
    /// Consumes whitespace then a balanced `open`…`close` run,
    /// returning its interior and advancing `cursor` past it.
    /// String literals are skipped so a brace or paren inside
    /// one cannot unbalance the walk.
    ///
    /// The literal skip is `literalEnd`'s, not a second one of
    /// its own: this file used to carry two walkers, and the
    /// inline copy handled neither `"""` nor `#"…"#` while
    /// claiming the trees used neither shape — six files in
    /// `Sources/KiwiDeskCore` do, and the bounds-routing guards
    /// walk that tree. Two walkers in the file `tests.md`
    /// ratifies precisely against divergent walkers is the harm
    /// arriving inside its own exception.
    static func balanced(
        _ text: [Character],
        from cursor: inout Int,
        open: Character,
        close: Character
    ) -> String? {
        var i = cursor
        while i < text.count, text[i].isWhitespace { i += 1 }
        guard i < text.count, text[i] == open else { return nil }
        var depth = 0
        let start = i + 1
        while i < text.count {
            if let end = literalEnd(text, from: i) {
                i = end
                continue
            }
            let character = text[i]
            if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0 {
                    cursor = i + 1
                    return String(text[start..<i])
                }
            }
            i += 1
        }
        return nil
    }

    /// Cuts each line at its first `//`, then removes `/* … */`
    /// spans. Note the direction depends on the
    /// consumer: for a *counting* guard a mis-cut erases a call
    /// and so fails OPEN, where for the balanced-walker consumers
    /// below it fails shut, as a mystifying red rather than a
    /// silent pass.
    ///
    /// The block half is not decoration: this used to say the
    /// repo has "no `/* */` convention" and stop at `//`, which
    /// made every positive needle in every consumer satisfiable
    /// by commenting the call out in block form — a guard-prover
    /// run deleted an `.accessibilityHidden` modifier, restated
    /// it as `/* … */`, and the needle stayed green over a view
    /// that had shipped the defect. A convention nobody follows
    /// is not a guarantee; the stripper is what has to hold.
    ///
    /// Line comments go first, and the order is load-bearing: a
    /// doc comment may legitimately contain `/*` (a glob such as
    /// `Resources/Locales/*.json` does), and stripping blocks
    /// first would open a comment there and swallow source until
    /// the next `*/`.
    ///
    /// Both halves skip string literals, since `stripped` asks
    /// `literalEnd` before either marker — a `//` inside a
    /// literal is never a comment. An unbalanced quote must
    /// still not send the walk to EOF, which is why `close`
    /// refuses an unterminated literal.
    ///
    /// `SourceScanCommentTests` holds the whole-file property
    /// this once broke — every line carrying no comment marker
    /// survives verbatim — because a scan handed less source
    /// than it thinks cannot red on its own.
    /// `blankingCommentsAndLiterals` is the same walk with the
    /// other emit policy (`SourceScan+Literals.swift`).
    static func stripComments(_ source: String) -> String {
        stripped(Array(source))
    }

    /// ONE walk for both comment shapes, tracking string
    /// literals as it goes — and the single pass is the point,
    /// not a tidy-up.
    ///
    /// Two defects came out of doing it in two passes. A naive
    /// block pass truncated three suites in `Tests/` at an
    /// unterminated `/*` inside a literal —
    /// `entry.hasSuffix("/**")` and two others, one of them this
    /// file, whose own `"/*"` and `"*/"` literals blanked 146
    /// characters of the function you are reading. Making only
    /// the block half literal-aware then left a subtler one: a
    /// line pass that cuts `"https://…"` at the `//` strands the
    /// opening quote, which INVERTS literal-vs-code parity for
    /// every paired quote after it — so the walk copied real code
    /// verbatim, stripping nothing, through most of five suites
    /// (`LinkedCaptionHitTests` at 151 of 281 insertion points).
    /// A scan cannot red for having been handed source with the
    /// comments still in it any more than for having been handed
    /// less.
    ///
    /// Spans **nest**, as they do in Swift, so
    /// `/* outer /* inner */ tail */` leaves nothing behind
    /// rather than stranding `tail */` for a needle to match. A
    /// `//` inside a span is already gone with the span; an
    /// unterminated `/*` outside a literal takes the rest of the
    /// file, which is what the compiler does with it too.
    ///
    /// Newlines are always emitted, inside a span or a line
    /// comment alike, so the stripped form stays line-for-line
    /// aligned with the source — `SourceScanCommentTests`
    /// compares the two by index, which is only exact because of
    /// that.
    ///
    /// `blanking` is the one other emit policy: what the drop
    /// policy removes becomes a space, position for position,
    /// and a literal keeps its delimiters and loses its interior
    /// — the blanker's contract. One walk, two policies, so a
    /// hardening here (nesting, marker order, the literal skip)
    /// cannot land in one and not the other (#1320).
    static func stripped(
        _ text: [Character],
        blanking: Bool = false
    ) -> String {
        var out = ""
        var depth = 0
        var i = 0
        func drop(_ character: Character) {
            if blanking {
                out.append(character == "\n" ? "\n" : " ")
            } else if character == "\n" {
                out.append("\n")
            }
        }
        while i < text.count {
            if depth == 0, let literal = literalSpan(text, from: i) {
                if blanking {
                    let open = i + literal.delimiter
                    let close = literal.end - literal.delimiter
                    out += String(text[i..<open])
                    for j in open..<close { drop(text[j]) }
                    out += String(text[close..<literal.end])
                } else {
                    out += String(text[i..<literal.end])
                }
                i = literal.end
                continue
            }
            if matches(text, at: i, openSpan) {
                depth += 1
                drop("/")
                drop("*")
                i += 2
                continue
            }
            if depth > 0, matches(text, at: i, closeSpan) {
                depth -= 1
                drop("*")
                drop("/")
                i += 2
                continue
            }
            if depth == 0, matches(text, at: i, lineComment) {
                while i < text.count, text[i] != "\n" {
                    drop(text[i])
                    i += 1
                }
                continue
            }
            if depth == 0 { out.append(text[i]) } else { drop(text[i]) }
            i += 1
        }
        return out
    }

    /// The index just past the string literal starting at `i`, or
    /// nil when nothing starts there. Handles the three shapes
    /// the scanned trees use — `"…"` with escapes, `"""…"""`, and
    /// the raw `#"…"#` — because each of them can legally carry a
    /// `/*` that is not a comment. `balanced` and `stripped` (and
    /// through it the blanker, #1320) route here. A sibling that
    /// still carries a plain-quote toggle of its own states its
    /// residue where it lives, and is routed here the day it
    /// bites — never copied.
    ///
    /// Residue, stated because it fails OPEN: an interpolation
    /// carrying a nested literal (`"\(dict["k"])"`) desyncs the
    /// quote pairing, so a `/* … */` inside the desynced region
    /// is copied unstripped — the defect the block half exists
    /// to close, in a narrow window. Nothing in either tree
    /// writes that shape today; handling it means tracking
    /// `\(` … `)` depth inside a literal, which is the next
    /// widening rather than this one.
    private static func literalEnd(
        _ text: [Character],
        from i: Int
    ) -> Int? {
        literalSpan(text, from: i)?.end
    }

    /// `literalEnd` plus the width of the literal's delimiter —
    /// what the blanking policy needs to keep the delimiters and
    /// blank only the interior, position for position.
    private static func literalSpan(
        _ text: [Character],
        from i: Int
    ) -> (end: Int, delimiter: Int)? {
        if matches(text, at: i, rawQuote) {
            return close(
                text,
                from: i + 2,
                on: rawEnd,
                escaped: false
            ).map { ($0, 2) }
        }
        if matches(text, at: i, tripleQuote) {
            return close(
                text,
                from: i + 3,
                on: tripleQuote,
                escaped: true
            ).map { ($0, 3) }
        }
        if text[i] == "\"" {
            return close(text, from: i + 1, on: quote, escaped: true)
                .map { ($0, 1) }
        }
        return nil
    }

    /// Scans to `delimiter`, honouring `\` escapes when the shape
    /// has them. **Nil when the delimiter never arrives**, so the
    /// caller treats the quote as an ordinary character and keeps
    /// stripping.
    ///
    /// That arm is not defensive coding: a literal walk that ran
    /// to EOF on an unbalanced quote would copy the rest of the
    /// file verbatim and strip no comments in it at all — the
    /// fail-open shape the whole family exists to refuse.
    private static func close(
        _ text: [Character],
        from start: Int,
        on delimiter: [Character],
        escaped: Bool
    ) -> Int? {
        var i = start
        while i < text.count {
            if escaped, text[i] == "\\" {
                i += 2
                continue
            }
            if matches(text, at: i, delimiter) {
                return i + delimiter.count
            }
            i += 1
        }
        return nil
    }

    /// Takes the needle as characters rather than a `String`:
    /// this runs up to twice per character of every file every
    /// scan guard reads, and an `Array(needle)` inside it cost
    /// millions of small allocations per suite.
    private static func matches(
        _ text: [Character],
        at i: Int,
        _ needle: [Character]
    ) -> Bool {
        guard i + needle.count <= text.count else { return false }
        for (offset, character) in needle.enumerated()
        where text[i + offset] != character {
            return false
        }
        return true
    }

    private static let lineComment: [Character] = ["/", "/"]
    private static let openSpan: [Character] = ["/", "*"]
    private static let closeSpan: [Character] = ["*", "/"]
    private static let rawQuote: [Character] = ["#", "\""]
    private static let rawEnd: [Character] = ["\"", "#"]
    private static let tripleQuote: [Character] = ["\"", "\"", "\""]
    private static let quote: [Character] = ["\""]
}
