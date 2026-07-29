import Foundation
import Testing

/// Every `var onLog` seam declared under `Sources/KiwiDeskCore`
/// must be assigned in `KiwiCore+Bootstrap.swift` — the one place
/// a subsystem's diagnostics are joined to `KiwiCore.onLog`, and
/// so to syslog.
///
/// The failure this prevents is **nothing happening.** An
/// unassigned seam keeps its default — `{ _ in }` for four of the
/// seven — so the subsystem compiles, ships, runs, and throws its
/// diagnostics away. Nothing reds, nothing warns, and the only
/// symptom is a log line that was never going to appear, missed
/// months later by whoever needed it. #599 was findable because a
/// spring divergence was loud; #611 named the same trap — an
/// unobservable rescue is how a loud failure becomes a quiet one
/// — and wired `AnimationEngine.onLog` on the spot.
/// `SocketServer.onLog` had been declared and never assigned
/// since it was written, six seams wired beside it in the same
/// function. The omission cost nothing to make and showed
/// nowhere.
///
/// **The lens, not the list.** Both ends are discovered: the seam
/// owners by scanning every Swift file in the target for
/// `var onLog` and walking each declaration back to its enclosing
/// type, and the wired set by resolving each receiver assigned in
/// bootstrap through the stored-property declaration that gives
/// it a type. A seam added to a subsystem that does not exist yet
/// is inside the net on arrival, and no list here is touched to
/// keep it there.
///
/// The resolver's limits all fail **shut** — a red naming what it
/// could not resolve, never a silent pass. It reads stored
/// properties at type scope (four-space indent), so a seam owner
/// held by a nested type resolves to nothing and reds; a property
/// name two types share resolves ambiguously and reds. Both want
/// a human, and neither is reachable today.
///
/// It lives in the GUI test target purely because `SourceScan`
/// does — `VisibleBoundsRoutingTests` makes the same trade. It
/// scans `Sources/KiwiDeskCore`; the GUI tree declares no seam.
@Suite("Log-seam wiring")
struct LogSeamWiringTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    private var bootstrapFile: URL {
        coreRoot.appendingPathComponent(
            "App/KiwiCore+Bootstrap.swift"
        )
    }

    /// Seam owners deliberately left out of bootstrap, and why.
    ///
    /// **This map is the exemption list** — AGENTS.md §5 and
    /// `.claude/rules/parity-tests.md` carry the principle and
    /// point here rather than restating who qualifies. Each entry
    /// is checked both ways: its type must still declare a seam
    /// and must still be unwired, so a stale exemption reds
    /// instead of quietly excusing a real one.
    private let allowed: [String: String] = [
        // The sink, not a seam: what every other seam forwards
        // *to*. It defaults to NSLog rather than to a no-op, and
        // wiring it to itself would recurse.
        "KiwiCore": "the syslog sink every other seam feeds"
    ]

    @Test("Every declared onLog seam is wired in bootstrap")
    func everySeamReachesTheSink() throws {
        let sources = try SourceScan.swiftSources(under: coreRoot)
        var unresolved: [String] = []
        let owners = try seamOwners(in: sources, gaps: &unresolved)
        let wired = try wiredOwners(
            properties: try storedProperties(in: sources),
            gaps: &unresolved
        )

        #expect(
            unresolved.isEmpty,
            Comment(
                rawValue: "the scan could not resolve "
                    + unresolved.sorted().joined(separator: "; ")
            )
        )

        for owner in owners.sorted() where allowed[owner] == nil {
            #expect(
                wired.contains(owner),
                Comment(
                    rawValue: "\(owner) declares a `var onLog` "
                        + "seam that KiwiCore+Bootstrap.swift "
                        + "never assigns, so its diagnostics "
                        + "reach nothing. Wire it beside the "
                        + "others, or record why it is exempt in "
                        + "this suite's `allowed` map."
                )
            )
        }

        // The inverse, which is also what proves the scan reached
        // real files: a mistyped root finds no seam at all, and
        // the loop above then passes without asserting once.
        for (owner, why) in allowed.sorted(by: { $0.key < $1.key }) {
            #expect(
                owners.contains(owner),
                Comment(
                    rawValue: "\(owner) no longer declares a "
                        + "`var onLog` seam (\(why)) — drop its "
                        + "`allowed` entry so the guard keeps "
                        + "biting."
                )
            )
            #expect(
                !wired.contains(owner),
                Comment(
                    rawValue: "\(owner) is exempt (\(why)) yet "
                        + "bootstrap now wires it — drop its "
                        + "`allowed` entry."
                )
            )
        }
    }

    // MARK: - Discovery

    /// The type enclosing each `var onLog` declaration.
    private func seamOwners(
        in sources: [URL],
        gaps: inout [String]
    ) throws -> Set<String> {
        let declaration = try regex(
            #"(?:^|\s)(?:class|struct|actor|enum|extension"#
                + #"|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)"#
        )
        var owners: Set<String> = []
        for file in sources {
            let lines = try strippedLines(of: file)
            for seam in seams(in: lines, declaration: declaration) {
                guard let owner = seam.owner else {
                    gaps.append(
                        "the type declaring `var onLog` at "
                            + "\(file.lastPathComponent):"
                            + "\(seam.line + 1)"
                    )
                    continue
                }
                owners.insert(owner)
            }
        }
        return owners
    }

    /// Each `var onLog` line in one file with the type that
    /// encloses it, from a forward walk carrying a brace-depth
    /// type stack.
    ///
    /// The stack is the whole point. Walking *backwards* to the
    /// nearest preceding declaration reads a closed **sibling**
    /// as the owner: `BorderManager.Spec` is declared above
    /// `BorderManager.onLog`, and the first draft of this guard
    /// reported the seam's owner as `Spec` — a red on a healthy
    /// tree, which is how a guard gets weakened into silence.
    ///
    /// `extension` and `protocol` push like any other: a seam
    /// declared in either resolves to that name and is then
    /// judged the same way.
    private func seams(
        in lines: [Substring],
        declaration: NSRegularExpression
    ) -> [(line: Int, owner: String?)] {
        var found: [(line: Int, owner: String?)] = []
        var stack: [(name: String, depth: Int)] = []
        var pending: String?
        var depth = 0
        for (index, line) in lines.enumerated() {
            if line.contains("var onLog") {
                found.append((index, stack.last?.name))
            }
            if let name = captures(
                declaration,
                in: String(line),
                [1]
            ).first?[1] {
                pending = name
            }
            var inString = false
            var escaped = false
            for character in line {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString.toggle()
                } else if inString {
                    continue
                } else if character == "{" {
                    depth += 1
                    if let name = pending {
                        stack.append((name, depth))
                        pending = nil
                    }
                } else if character == "}" {
                    if stack.last?.depth == depth {
                        stack.removeLast()
                    }
                    depth -= 1
                }
            }
        }
        return found
    }

    /// The seam owners bootstrap actually assigns, found by
    /// resolving each receiver (`crash`, `tiler.animation`)
    /// through its stored-property declaration.
    private func wiredOwners(
        properties: [String: Set<String>],
        gaps: inout [String]
    ) throws -> Set<String> {
        let source = SourceScan.stripComments(
            try String(contentsOf: bootstrapFile, encoding: .utf8)
        )
        let assignment = try regex(
            #"([A-Za-z_][A-Za-z0-9_.]*)\.onLog\s*="#
        )
        var owners: Set<String> = []
        for match in captures(assignment, in: source, [1]) {
            guard let receiver = match[1] else { continue }
            let leaf = receiver.split(separator: ".").last
                .map(String.init)
            guard let types = leaf.flatMap({ properties[$0] }),
                types.count == 1, let owner = types.first
            else {
                gaps.append(
                    "the type of `\(receiver)`, assigned "
                        + "`.onLog` in KiwiCore+Bootstrap.swift"
                )
                continue
            }
            owners.insert(owner)
        }
        return owners
    }

    /// Every stored property declared at type scope, as
    /// name → declared types. A name keeps a *set* so a collision
    /// resolves to nothing above, rather than to whichever
    /// declaration the walk happened to reach last.
    private func storedProperties(
        in sources: [URL]
    ) throws -> [String: Set<String>] {
        let property = try regex(
            #"^ {4}(?:[a-z]+(?:\(set\))?\s+)*(?:let|var)\s+"#
                + #"([A-Za-z_][A-Za-z0-9_]*)\s*"#
                + #"(?::\s*([A-Za-z_][A-Za-z0-9_]*)"#
                + #"|=\s*([A-Za-z_][A-Za-z0-9_]*)\()"#
        )
        var index: [String: Set<String>] = [:]
        for file in sources {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for match in captures(property, in: source, [1, 2, 3]) {
                guard let name = match[1],
                    let type = match[2] ?? match[3]
                else { continue }
                index[name, default: []].insert(type)
            }
        }
        return index
    }

    // MARK: - Primitives

    private func strippedLines(
        of file: URL
    ) throws -> [Substring] {
        SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(separator: "\n", omittingEmptySubsequences: false)
    }

    private func regex(
        _ pattern: String
    ) throws -> NSRegularExpression {
        try NSRegularExpression(
            pattern: pattern,
            options: [.anchorsMatchLines]
        )
    }

    /// Each match's requested capture groups, a group that did
    /// not participate simply absent.
    private func captures(
        _ regex: NSRegularExpression,
        in text: String,
        _ groups: [Int]
    ) -> [[Int: String]] {
        let whole = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: whole).map { match in
            var found: [Int: String] = [:]
            for group in groups {
                guard group < match.numberOfRanges,
                    let range = Range(
                        match.range(at: group),
                        in: text
                    )
                else { continue }
                found[group] = String(text[range])
            }
            return found
        }
    }
}
