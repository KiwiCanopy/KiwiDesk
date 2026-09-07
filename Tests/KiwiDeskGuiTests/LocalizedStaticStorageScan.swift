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
        let source = SourceScan.blankingCommentsAndLiterals(raw)
        let eager = Self.eagerlyLocalizingMembers(in: source)
        var offenders: [String] = []
        for (name, initializer) in Self.storedStatics(in: source) {
            let key = "\(tree)/\(file.lastPathComponent):\(name)"
            guard Self.allowed[key] == nil else { continue }
            let body = Self.blankingDeferredClosures(initializer)
            let reaches =
                Self.calls("L", in: body)
                || eager.contains { Self.references($0, in: body) }
            if reaches {
                offenders.append("  \(key)")
            }
        }
        return offenders
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
            if atLineStart, index > 0, characters[index - 1] != "\n" {
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
            let end = initializerEnd(characters, from: start)
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

    /// Where the initialiser that starts at `cursor` ends.
    private static func initializerEnd(
        _ text: [Character],
        from cursor: Int
    ) -> Int {
        let continuing: Set<Character> = [
            "=", ",", "{", "(", "[", ".", "+", "?", ":",
        ]
        var depth = 0
        var index = cursor
        var lineStart = cursor
        while index < text.count {
            let character = text[index]
            if "([{".contains(character) { depth += 1 }
            if ")]}".contains(character) { depth -= 1 }
            if character == "\n" {
                let line = text[lineStart..<index]
                let tail = line.last { !$0.isWhitespace }
                if depth <= 0, let tail, !continuing.contains(tail) {
                    return index
                }
                lineStart = index + 1
            }
            index += 1
        }
        return text.count
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
