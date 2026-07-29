import Foundation
import Testing

/// Every `var onLog` seam declared under `Sources/KiwiDeskCore`
/// must be assigned in a `KiwiCore+Bootstrap` file — the one place
/// a subsystem's diagnostics are joined to `KiwiCore.onLog`, and
/// so to syslog.
///
/// The failure this prevents is **nothing happening.** A seam
/// whose default is a no-op, left unassigned, lets its
/// subsystem compile, ship, run, and throw its diagnostics away.
/// Nothing reds, nothing warns, and the only symptom is a log
/// line that was never going to appear, missed months later by
/// whoever needed it. #599 was findable because a spring
/// divergence was loud; #611 named the same trap — an
/// unobservable rescue is how a loud failure becomes a quiet one
/// — and wired `AnimationEngine.onLog` on the spot.
/// `SocketServer.onLog` had been declared and never assigned
/// since it was written, six seams wired beside it in the same
/// function. The omission cost nothing to make and showed
/// nowhere.
///
/// **The lens, not the list.** Both ends are discovered: the seam
/// owners by scanning every Swift file in the target for
/// `var onLog:` and resolving each declaration's enclosing type,
/// and the wired set by resolving each receiver assigned in
/// bootstrap through the stored-property declaration that gives
/// it a type. A seam added to a subsystem that does not exist yet
/// is inside the net on arrival, and no list here is touched to
/// keep it there.
///
/// **What a source scan structurally cannot do**, and which of
/// it still binds here. The first three were open limits until
/// #625; `LogSeamProbeTests` closes them by reading final runtime
/// state instead of text, and they are kept written out because
/// they are the reason that suite exists — delete them and the
/// next author sees two guards over one invariant and removes
/// the wrong one:
///
/// - **Type**-keyed, not instance-keyed. Two instances of one
///   seam-owning type with only one wired passes this scan.
/// - **Assigned**, not routed: `socket.onLog = { _ in }` in
///   bootstrap satisfies it completely, and no cheap scan does
///   better — pinning the closure body would red on any refactor
///   of a line that is correct.
/// - **Assigned**, not assigned *exactly once*. This counts
///   assignments in text and has no notion of last-writer-wins,
///   so a seam wired correctly in the group and then clobbered
///   by a stale duplicate elsewhere passes. That shape arrives
///   by silent auto-merge rather than by anything a reviewer
///   reads.
///
/// What this suite still owns, and why it is not redundant: it
/// sees a seam on a type that `makeTestCore` never instantiates,
/// which no runtime walk can reach, and it names the *rule*
/// (wired in bootstrap, in the group) rather than the outcome.
///
/// - Everything the resolver cannot work out fails **shut**, as
///   a red naming what it could not resolve: an unrecognised
///   assignment shape, a receiver whose type is ambiguous or
///   undeclared, a seam whose enclosing type the walk missed.
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

    /// Bootstrap by **prefix**, because the rule is written
    /// "wired in `KiwiCore+Bootstrap`" and that file grows with
    /// every subsystem. A split into `KiwiCore+Bootstrap2` would
    /// otherwise red every seam at once, over a change that
    /// honours the rule exactly.
    private func bootstrapFiles() throws -> [URL] {
        try SourceScan.swiftSources(
            under: coreRoot.appendingPathComponent("App")
        )
        .filter {
            $0.lastPathComponent.hasPrefix("KiwiCore+Bootstrap")
        }
    }

    /// Seam owners deliberately left out of bootstrap, and why.
    ///
    /// **This map is the exemption list** — AGENTS.md §5 and
    /// `.claude/rules/core-boundaries.md` carry the principle and
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
                        + "seam that no KiwiCore+Bootstrap file "
                        + "assigns, so its diagnostics reach "
                        + "nothing. Wire it beside the others, "
                        + "or record why it is exempt in this "
                        + "suite's `allowed` map."
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

    /// The type enclosing each `var onLog:` declaration. The
    /// colon is load-bearing: without it a future `onLogLevel`
    /// registers as a seam and demands a wiring it has no use
    /// for.
    private func seamOwners(
        in sources: [URL],
        gaps: inout [String]
    ) throws -> Set<String> {
        var owners: Set<String> = []
        for file in sources {
            let lines = try strippedLines(of: file)
            let enclosing = SourceScan.enclosingTypes(of: lines)
            for index in lines.indices
            where lines[index].contains("var onLog:") {
                guard let owner = enclosing[index] else {
                    gaps.append(
                        "the type declaring `var onLog` at "
                            + "\(file.lastPathComponent):"
                            + "\(index + 1)"
                    )
                    continue
                }
                owners.insert(owner)
            }
        }
        return owners
    }

    /// The seam owners bootstrap actually assigns, found by
    /// resolving each receiver (`crash`, or `tiler.animation`
    /// once #611 lands) through its stored-property declaration.
    private func wiredOwners(
        properties: [String: Set<String>],
        gaps: inout [String]
    ) throws -> Set<String> {
        var owners: Set<String> = []
        for file in try bootstrapFiles() {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let receivers = SourceScan.allMatches(
                in: source,
                pattern: #"([A-Za-z_][A-Za-z0-9_.]*)\.onLog\s*="#
            )
            // That pattern knows one wiring shape.
            // `luaEngine?.onLog =` and `engines[0].onLog =` match
            // nothing at all, and the seam would then read as
            // *unwired* — a red carrying the wrong message, which
            // is worse than no red. So count the bare
            // assignments too and gap on the difference.
            //
            // A regex and not `occurrences(of: ".onLog =")`,
            // which would tie the count to one spacing: an
            // unreadable `socket?.onLog = x` would then be
            // masked by a readable `bus.onLog=x` elsewhere in
            // the file, since the literal counts neither. That
            // is unreachable while swift-format normalises `=`
            // spacing, and a guard resting on a formatter rule
            // is a guard that a formatter change can quietly
            // switch off (review).
            let bare = SourceScan.allMatches(
                in: source,
                pattern: #"(\.onLog)\s*="#
            ).count
            if bare > receivers.count {
                gaps.append(
                    "\(bare - receivers.count) `.onLog =` "
                        + "assignment(s) in "
                        + "\(file.lastPathComponent) written in "
                        + "a shape this scan cannot read"
                )
            }
            for receiver in receivers {
                guard
                    let owner = resolve(receiver, in: properties)
                else {
                    gaps.append(
                        "the type of `\(receiver)`, assigned "
                            + "`.onLog` in "
                            + file.lastPathComponent
                    )
                    continue
                }
                owners.insert(owner)
            }
        }
        return owners
    }

    /// A receiver's declared type, or `nil` when the index holds
    /// no entry for its name or holds more than one — an
    /// ambiguous name is refused rather than resolved to
    /// whichever declaration the scan reached last.
    private func resolve(
        _ receiver: String,
        in properties: [String: Set<String>]
    ) -> String? {
        guard let leaf = receiver.split(separator: ".").last,
            let types = properties[String(leaf)],
            types.count == 1
        else { return nil }
        return types.first
    }

    /// Every stored property declared at type scope, as
    /// name → declared types. A name keeps a *set* so a collision
    /// is refused above rather than resolved arbitrarily.
    private func storedProperties(
        in sources: [URL]
    ) throws -> [String: Set<String>] {
        // The type capture is deliberately upper-case-initial.
        // Accepting any word reads `var x: any P` as the type
        // `any` and `var x = makeThing()` as the type
        // `makeThing`, and since either resolves to exactly one
        // name the junk is then accepted **silently** — the one
        // way this scan could pass for the wrong reason. Both
        // shapes exist in the tree today.
        let pattern =
            #"^ {4}(?:[a-z]+(?:\(set\))?\s+)*(?:let|var)\s+"#
            + #"([A-Za-z_][A-Za-z0-9_]*)\s*"#
            + #"(?::\s*([A-Z][A-Za-z0-9_]*)"#
            + #"|=\s*([A-Z][A-Za-z0-9_]*)\()"#
        var index: [String: Set<String>] = [:]
        for file in sources {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for match in SourceScan.allMatchGroups(
                in: source,
                pattern: pattern,
                groups: [1, 2, 3],
                options: [.anchorsMatchLines]
            ) {
                guard let name = match[1],
                    let type = match[2] ?? match[3]
                else { continue }
                index[name, default: []].insert(type)
            }
        }
        return index
    }

    private func strippedLines(
        of file: URL
    ) throws -> [Substring] {
        SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(separator: "\n", omittingEmptySubsequences: false)
    }
}
