import Foundation

/// The scan half of `LocalizedStaticStorageTests` (#1311) — held
/// apart because it walks source rather than asserting on it, and
/// because the suite reached the 350-line ceiling.
///
/// The hardened pieces are REUSED, never copied — `balanced`,
/// `blankingCommentsAndLiterals`, `memberBodies`,
/// `isIdentifier` — which is the drift that family exists to
/// prevent, and `blankingCommentsAndLiterals`' own residue is
/// therefore inherited too (#1320).
///
/// What is genuinely new here, and so stays the suite's own at
/// the family's FIRST-consumer line: the `=`-initialiser bounds
/// `memberBodies` states it does not walk, and an
/// offset-returning needle (`occurrences`) that `callSites` and
/// `mentions` do not offer. `starts` is the one second copy —
/// `SourceScan+Declarations`' is `private` and hardcodes the
/// opposite `orDot` — and it is named rather than left to look
/// like reuse.
extension LocalizedStaticStorageTests {

    /// Every `static let` in `file` whose initialiser reaches
    /// `L()` eagerly, reported as `tree/File.swift:name`.
    func frozen(
        in file: URL,
        tree: String
    ) throws -> [String] {
        let raw = try SourceScan.rawSource(at: file)
        // A file with neither spelling cannot offend, and the
        // fixpoint below is the scan's whole cost.
        guard raw.contains("L("),
            Self.storingSpellings.contains(
                where: { raw.contains($0.0) }
            )
        else { return [] }
        return Self.frozenNames(in: raw).compactMap { name in
            let key = "\(tree)/\(file.lastPathComponent):\(name)"
            guard Self.allowed[key] == nil else { return nil }
            return "  \(key)"
        }
    }

    /// The stored declarations in `raw` that reach `L()` while
    /// being initialised, by name.
    ///
    /// Split from `frozen` so the predicate can be driven over
    /// hand-written source: `LocalizedStaticStorageFixtureTests`
    /// is what makes `storingSpellings` and the walkers
    /// load-bearing, since a row deleted from a hand-listed
    /// register is otherwise a silent shrink (`guard-prover`,
    /// #1311).
    static func frozenNames(in raw: String) -> [String] {
        let source = SourceScan.blankingCommentsAndLiterals(raw)
        let eager = eagerlyLocalizingMembers(in: source)
        var found: [String] = []
        for (name, initializer) in storedStatics(in: source) {
            let body = blankingDeferredClosures(initializer)
            let reaches =
                calls("L", in: body)
                || eager.contains { references($0, in: body) }
            if reaches { found.append(name) }
        }
        return found
    }

    /// Members of `source` whose body hands a RESOLVED localized
    /// string back to its caller — the indirection
    /// `AppBarOptions.edge` used, and the reason this scan does
    /// not stop at a direct `L(`.
    ///
    /// Iterated to a fixpoint so a two-hop helper counts too. A
    /// member whose `L()` sits inside a deferred closure hands
    /// back the CLOSURE and is not eager (`awayMark`).
    static func eagerlyLocalizingMembers(
        in source: String
    ) -> Set<String> {
        let members = SourceScan.memberBodies(in: source)
            .map { ($0.declaration, blankingDeferredClosures($0.body)) }
        var eager: Set<String> = []
        var grew = true
        while grew {
            grew = false
            for (name, body) in members where !eager.contains(name) {
                guard
                    calls("L", in: body)
                        || eager.contains(where: {
                            references($0, in: body)
                        })
                else { continue }
                eager.insert(name)
                grew = true
            }
        }
        return eager
    }

    /// The spellings that store a value for the life of whatever
    /// owns them, and whether the spelling is only a store at the
    /// START of a line.
    ///
    /// The subject is the STORE, not one spelling. `static let`
    /// and `static var` are both lazily-initialised globals —
    /// the FIRST cut watched `static let` alone while telling the
    /// next author to "reach for a computed `static var`", which
    /// aimed them at the uncovered half. `lazy var` freezes for
    /// as long as its object lives, which is the process when
    /// that object is a singleton (`ColorPanelController.shared`,
    /// the site the `static let`-only cut was blind to). A bare
    /// `let` counts only at column zero, where it is a global; a
    /// `let` inside a body dies with its call.
    ///
    /// A COMPUTED property is not a store and is not matched:
    /// `assignment` returns nil at the `{` that opens a body.
    /// What this TRADES is a stored `static var` carrying a
    /// `didSet`, whose observer body is swallowed into the
    /// captured initialiser — over-capture, which fails SHUT as
    /// a false red rather than a hole.
    static let storingSpellings: [(String, atLineStart: Bool)] = [
        ("static let ", atLineStart: false),
        ("static var ", atLineStart: false),
        ("lazy var ", atLineStart: false),
        ("let ", atLineStart: true),
    ]

    /// Each stored declaration in `source` paired with the text
    /// of its `=` initialiser.
    ///
    /// `SourceScan.memberBodies` deliberately skips a property
    /// reached through `=`, which is precisely the shape this
    /// guard is about, so the bounds are walked here: from the
    /// `=` until bracket depth returns to zero on a line that
    /// does not end in a continuation. Under-capturing fails
    /// OPEN, so the walk is proved by mutation rather than
    /// trusted (`guard-prover`, #1311).
    static func storedStatics(
        in source: String
    ) -> [(name: String, initializer: String)] {
        storingSpellings.flatMap {
            stored(in: source, after: $0.0, atLineStart: $0.1)
        }
    }

    /// The stored declarations `source` introduces with `marker`.
    private static func stored(
        in source: String,
        after marker: String,
        atLineStart: Bool
    ) -> [(name: String, initializer: String)] {
        let characters = Array(source)
        let marker = Array(marker)
        var found: [(String, String)] = []
        var index = 0
        while index + marker.count < characters.count {
            guard
                Array(characters[index..<(index + marker.count)])
                    == marker
            else {
                index += 1
                continue
            }
            if atLineStart, !atColumnZero(characters, index) {
                index += 1
                continue
            }
            var cursor = index + marker.count
            let name = String(
                characters[cursor...].prefix {
                    SourceScan.isIdentifier($0, orDot: false)
                }
            )
            cursor += name.count
            guard let start = assignment(characters, from: cursor)
            else {
                index = cursor
                continue
            }
            let end = initializerEnd(
                characters,
                from: start,
                indent: lineIndent(characters, at: index)
            )
            found.append((name, String(characters[start..<end])))
            index = end
        }
        return found
    }

    /// The offset just past the `=` that opens the initialiser,
    /// or nil when the declaration opens a computed body (`{`) or
    /// ends without one.
    private static func assignment(
        _ text: [Character],
        from cursor: Int
    ) -> Int? {
        var index = cursor
        while index < text.count {
            switch text[index] {
            case "=": return index + 1
            case "{", "\n": return nil
            default: index += 1
            }
        }
        return nil
    }

    /// Where the initialiser that starts at `cursor` ends: an
    /// unbalanced bracket continues it, and so does a following
    /// line INDENTED past the declaration.
    ///
    /// Indentation rather than a set of trailing operators. The
    /// first cut listed the characters a continued line may end
    /// on, and `guard-prover` walked straight through it with a
    /// ternary — `Bool.random()` ends on `)`, so the walk stopped
    /// one line above the `? L(…)` and the freeze went unseen.
    /// Any leading-operator continuation (`+`, `??`, `.`) is the
    /// same shape. `swift format` owns the indentation this
    /// leans on, so the two move together.
    ///
    /// What it TRADES: over-capture. A declaration followed by a
    /// more-indented line that is NOT its continuation is read as
    /// one, which fails SHUT — a false red naming the wrong
    /// declaration, never a hole.
    private static func initializerEnd(
        _ text: [Character],
        from cursor: Int,
        indent: Int
    ) -> Int {
        var depth = 0
        var index = cursor
        while index < text.count {
            let character = text[index]
            if "([{".contains(character) { depth += 1 }
            if ")]}".contains(character) { depth -= 1 }
            if character == "\n", depth <= 0,
                nextIndent(text, after: index) <= indent
            {
                return index
            }
            index += 1
        }
        return text.count
    }

    /// The indentation of the first non-empty line after
    /// `newline`, or `0` at end of file.
    private static func nextIndent(
        _ text: [Character],
        after newline: Int
    ) -> Int {
        var index = newline + 1
        while index < text.count {
            var width = 0
            while index < text.count, text[index] == " " {
                width += 1
                index += 1
            }
            guard index < text.count else { return 0 }
            if text[index] == "\n" {
                index += 1
                continue
            }
            return width
        }
        return 0
    }

    /// The indentation of the line `offset` sits on.
    private static func lineIndent(
        _ text: [Character],
        at offset: Int
    ) -> Int {
        var start = offset
        while start > 0, text[start - 1] != "\n" { start -= 1 }
        var width = 0
        while start + width < text.count,
            text[start + width] == " "
        {
            width += 1
        }
        return width
    }

    /// Whether the line `offset` sits on begins at column zero —
    /// which, for a bare `let`, is what makes it a global.
    ///
    /// The LINE rather than the keyword: `guard-prover` walked a
    /// `@MainActor let x = L(…)` past a cut that asked whether
    /// the `let` itself was preceded by a newline. Any modifier
    /// spelled ahead of it has the same effect.
    private static func atColumnZero(
        _ text: [Character],
        _ offset: Int
    ) -> Bool {
        lineIndent(text, at: offset) == 0
    }

    /// `text` with every deferred `{ … }` run blanked, so what is
    /// left is what runs at initialisation.
    static func blankingDeferredClosures(_ text: String) -> String {
        var characters = Array(text)
        var index = 0
        while index < characters.count {
            guard
                let introducer = deferredIntroducers.first(where: {
                    starts(characters, at: index, $0)
                })
            else {
                index += 1
                continue
            }
            var cursor = index + introducer.count
            let opened = cursor
            guard
                SourceScan.balanced(
                    characters,
                    from: &cursor,
                    open: "{",
                    close: "}"
                ) != nil
            else {
                index += introducer.count
                continue
            }
            for blank in opened..<cursor where characters[blank] != "\n" {
                characters[blank] = " "
            }
            index = cursor
        }
        return String(characters)
    }
}
