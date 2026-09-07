import Foundation

/// The scan half of `LocalizedStaticStorageTests` (#1311) — held
/// apart because it walks source rather than asserting on it, and
/// because the suite reached the 350-line ceiling.
///
/// These walkers are the suite's own rather than `SourceScan`'s:
/// that family extracts a primitive at its SECOND consumer, and
/// this is the first. The shared, hardened pieces — `balanced`,
/// `blankingCommentsAndLiterals`, `memberBodies`, `isIdentifier`
/// — are reused rather than copied, which is the drift the family
/// exists to prevent.
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
        guard raw.contains("static let "), raw.contains("L(")
        else { return [] }
        let source = SourceScan.blankingCommentsAndLiterals(raw)
        let eager = Self.eagerlyLocalizingMembers(in: source)
        var offenders: [String] = []
        for (name, initializer) in Self.storedStatics(in: source) {
            let key = "\(file.lastPathComponent):\(name)"
            guard Self.allowed[key] == nil else { continue }
            let body = Self.blankingDeferredClosures(initializer)
            let reaches =
                Self.calls("L", in: body)
                || eager.contains { Self.references($0, in: body) }
            if reaches {
                offenders.append("  \(tree)/\(key)")
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

    /// Each `static let` in `source` paired with the text of its
    /// `=` initialiser.
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
        let characters = Array(source)
        let marker = Array("static let ")
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

    /// Whether `text` CALLS the free function `name` — the
    /// identifier followed by `(`, on a boundary, and not
    /// dot-prefixed, so a `Foo.L(` of someone else's never
    /// answers for ours.
    private static func calls(
        _ name: String,
        in text: String
    ) -> Bool {
        occurrences(of: name, in: text, dotted: false).contains {
            next(after: $0, in: Array(text)) == "("
        }
    }

    /// Whether `text` READS the same-file member `name` — called
    /// (`label($0)`), qualified (`Self.title`) or bare.
    ///
    /// A member is not always a function: a computed `var`
    /// resolving `L()` is read without parentheses, and a
    /// call-only needle would leave every such indirection
    /// invisible. An argument LABEL is excluded — `label:` names
    /// a parameter, it does not read the member.
    private static func references(
        _ name: String,
        in text: String
    ) -> Bool {
        let characters = Array(text)
        return occurrences(of: name, in: text, dotted: true)
            .contains { next(after: $0, in: characters) != ":" }
    }

    /// Offsets just past each boundary-clean occurrence of
    /// `name`. `dotted` keeps `.name`, which a member read has
    /// and a free call must not.
    private static func occurrences(
        of name: String,
        in text: String,
        dotted: Bool
    ) -> [Int] {
        let characters = Array(text)
        let needle = Array(name)
        var found: [Int] = []
        var index = 0
        while index + needle.count <= characters.count {
            defer { index += 1 }
            guard
                Array(characters[index..<(index + needle.count)])
                    == needle
            else { continue }
            if index > 0,
                SourceScan.isIdentifier(
                    characters[index - 1],
                    orDot: !dotted
                )
            {
                continue
            }
            let after = index + needle.count
            if after < characters.count,
                SourceScan.isIdentifier(characters[after], orDot: false)
            {
                continue
            }
            found.append(after)
        }
        return found
    }

    /// The first non-whitespace character at or after `offset`.
    private static func next(
        after offset: Int,
        in text: [Character]
    ) -> Character? {
        var index = offset
        while index < text.count, text[index].isWhitespace {
            index += 1
        }
        return index < text.count ? text[index] : nil
    }

    /// Whether `needle` begins at `index` on an identifier
    /// boundary.
    private static func starts(
        _ text: [Character],
        at index: Int,
        _ needle: String
    ) -> Bool {
        let characters = Array(needle)
        guard index + characters.count <= text.count,
            Array(text[index..<(index + characters.count)])
                == characters
        else { return false }
        if index > 0,
            SourceScan.isIdentifier(text[index - 1], orDot: true)
        {
            return false
        }
        return true
    }
}
