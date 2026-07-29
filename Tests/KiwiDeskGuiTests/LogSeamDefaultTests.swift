import Foundation
import Testing

/// `CoreLog.write` is every seam's default and nothing else
/// (#624).
///
/// Three assertions, because the invariant has three halves and
/// each fails on its own:
///
/// 1. **Every `var onLog:` defaults to it.** `{ _ in }` is the
///    obvious thing to type when declaring a new seam, it
///    compiles, and the subsystem it silences is the one nobody
///    was reading yet — six of the eight seams carried exactly
///    that default until #624.
/// 2. **Its body still writes.** Nothing else in the tree looks
///    at what `CoreLog.write` *does*: the other seam guards all
///    assign `core.onLog` themselves, so none of them ever runs
///    the default. Gut the `NSLog` and the tree returns to its
///    pre-#624 behaviour with every seam still naming
///    `CoreLog.write` and every other guard green — and the
///    pressure to do exactly that is real, since these lines land
///    in the unified log during test runs.
/// 3. **Core reaches it only through a seam declaration.** It is
///    `internal`, but internal is the whole of `KiwiDeskCore`. A
///    direct `CoreLog.write("…")` call site would put a
///    diagnostic in syslog that `KiwiCore.onLog` never sees,
///    which is the routing failure the wiring rule exists to
///    prevent, wearing a blessed-looking spelling.
///
/// The argument for the default itself is on `CoreLog`, where an
/// author reaches it; the seam discovery is shared with
/// `LogSeamWiringTests` through `SourceScan.logSeamDeclarations`.
///
/// Companion to `LogSeamWiringTests`, not a duplicate: that one
/// catches a seam nobody wired, this one catches a seam whose
/// unwired state would be silent. Neither implies the other.
///
/// Deliberately line-scoped: it reads the default off the
/// declaration's own line and **gaps** — reds naming what it
/// could not read — on a declaration whose `=` is elsewhere, so a
/// wrapped shape fails shut with an honest message rather than as
/// "does not default to `CoreLog.write`".
@Suite("Log-seam defaults")
struct LogSeamDefaultTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    @Test("Every onLog seam defaults to CoreLog.write")
    func everySeamDefaultsToTheSyslogWrite() throws {
        let declarations = try SourceScan.logSeamDeclarations(
            under: coreRoot
        )

        try assertScanReachedTheTree(declarations)

        for declaration in declarations {
            guard let defaultValue = declaration.defaultValue
            else {
                Issue.record(
                    Comment(
                        rawValue: "\(declaration.site) declares "
                            + "`var onLog` in a shape this scan "
                            + "cannot read a default from — it "
                            + "expects the `=` on the "
                            + "declaration's own line"
                    )
                )
                continue
            }
            #expect(
                defaultValue == "CoreLog.write",
                Comment(
                    rawValue: "\(declaration.site) defaults its "
                        + "`onLog` seam to `\(defaultValue)`. "
                        + "Every seam defaults to `CoreLog.write` "
                        + "so that a seam running on its default "
                        + "skips the sink rather than dropping "
                        + "the line — see `CoreLog`."
                )
            )
        }
    }

    @Test("CoreLog.write still writes")
    func theDefaultStillReachesSyslog() throws {
        let source = try String(
            contentsOf: coreRoot.appendingPathComponent(
                "App/CoreLog.swift"
            ),
            encoding: .utf8
        )
        // The **balanced** body, not "everything after the
        // signature". `components(separatedBy:)` would run to
        // EOF, so a sibling declaration below carrying its own
        // `NSLog(` would satisfy this while `write` itself was
        // gutted — the guard passing for exactly the reason it
        // exists to catch. It passes today only because `write`
        // happens to be the file's last declaration, which is
        // not a property anything holds still.
        let body = try functionBody(
            of: "static func write",
            in: SourceScan.stripComments(source)
        )
        #expect(
            body?.contains("NSLog(") == true,
            Comment(
                rawValue: "`CoreLog.write` no longer calls "
                    + "`NSLog`. Nothing else in the tree asserts "
                    + "what this body does, so gutting it "
                    + "restores the pre-#624 silence with every "
                    + "seam still naming `CoreLog.write`. If the "
                    + "write is deliberately moving to `os_log` "
                    + "or similar, change this guard in the same "
                    + "commit rather than around it."
            )
        )
        #expect(
            body?.contains("#if") != true,
            Comment(
                rawValue: "`CoreLog.write`'s body is "
                    + "conditionally compiled — a build where "
                    + "the write vanishes is the failure this "
                    + "guard exists to catch"
            )
        )
    }

    /// The nearest non-blank line above `index`, or "" at the
    /// top of the file.
    private func previousCodeLine(
        before index: Int,
        in lines: [Substring]
    ) -> Substring {
        var cursor = index - 1
        while cursor >= 0,
            lines[cursor].trimmingCharacters(in: .whitespaces)
                .isEmpty
        {
            cursor -= 1
        }
        return cursor >= 0 ? lines[cursor] : ""
    }

    /// The balanced `{ … }` run following `signature`, or nil
    /// when the signature is not there — which the caller reds
    /// on, rather than silently checking an empty string.
    private func functionBody(
        of signature: String,
        in source: String
    ) throws -> String? {
        guard let range = source.range(of: signature) else {
            Issue.record(
                Comment(
                    rawValue: "CoreLog no longer declares "
                        + "`\(signature)` — this guard reads its "
                        + "body and cannot find it"
                )
            )
            return nil
        }
        let characters = Array(source)
        var cursor = source.distance(
            from: source.startIndex,
            to: range.upperBound
        )
        // Step over the parameter list, then take the brace run.
        guard
            SourceScan.balanced(
                characters,
                from: &cursor,
                open: "(",
                close: ")"
            ) != nil
        else { return nil }
        return SourceScan.balanced(
            characters,
            from: &cursor,
            open: "{",
            close: "}"
        )
    }

    @Test("Core reaches CoreLog only through a seam default")
    func theDefaultIsNeverCalledDirectly() throws {
        // Keyed on the full path, not the basename: two files of
        // one name under `Sources/KiwiDeskCore` would otherwise
        // let a declaration in the first mask a real direct call
        // at the same line number in the second. Nothing has that
        // shape today, which is exactly when it is cheap to rule
        // out.
        let declarationLines = Set(
            try SourceScan.logSeamDeclarations(under: coreRoot)
                .map { "\($0.file.path):\($0.line)" }
        )
        var callSites: [String] = []
        for file in try SourceScan.swiftSources(under: coreRoot)
        where file.lastPathComponent != "CoreLog.swift" {
            let lines = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(separator: "\n", omittingEmptySubsequences: false)
            for index in lines.indices
            where lines[index].contains("CoreLog.") {
                guard
                    !declarationLines.contains(
                        "\(file.path):\(index + 1)"
                    )
                else { continue }
                // A wrapped declaration puts the default on its
                // own line, which is not a call site. Without
                // this, that shape reds twice: once correctly
                // ("cannot read a default from") and once telling
                // the author to log through `onLog`, which is
                // what they were already doing.
                guard
                    !previousCodeLine(before: index, in: lines)
                        .contains("var onLog:")
                else { continue }
                callSites.append(
                    "\(file.lastPathComponent):\(index + 1)"
                )
            }
        }
        #expect(
            callSites.isEmpty,
            Comment(
                rawValue: "\(callSites.sorted().joined(separator: ", ")) "
                    + "names `CoreLog` outside a `var onLog:` "
                    + "declaration. It is a default, not a "
                    + "logging API — a direct call writes to "
                    + "syslog without passing `KiwiCore.onLog`, "
                    + "so nothing capturing that sink sees it. "
                    + "Log through the subsystem's own `onLog`."
            )
        )
    }

    /// The canary over the collection these tests consume.
    ///
    /// `SourceScan.swiftSources` answers `[]` for a directory that
    /// does not exist rather than throwing, so a mistyped root — or
    /// a narrowed file predicate, the harm `tests.md` names for
    /// this helper family — leaves the loops above asserting
    /// nothing at all.
    ///
    /// Two checks, and the algebra of the first is worth being
    /// careful about, because the obvious version reds a correct
    /// tree.
    ///
    /// **Distinct receivers, and `>=` not `>`.** Every receiver
    /// bootstrap assigns must be declared somewhere, so the
    /// declarations cannot be fewer than the distinct receivers.
    /// Counting raw assignments and demanding strictly more
    /// declarations looks tighter and is wrong: it spends a
    /// margin of exactly one, which two legitimate changes
    /// consume — wiring two instances of one seam-owning type
    /// (the shape `LogSeamWiringTests` documents as plausible)
    /// and assigning one seam in a second
    /// `KiwiCore+Bootstrap*.swift` (which its prefix match exists
    /// to allow). Both would then red naming a scan bug that is
    /// not there.
    ///
    /// **And an anchor in `App/`.** The count alone still passes
    /// a scan narrowed to skip `App/` entirely, which drops the
    /// bootstrap files and the sink together and so shrinks both
    /// sides at once. Requiring the sink's own declaration pins
    /// the one directory that failure hides in.
    ///
    /// Between them: a mistyped root reds, a narrowed file
    /// predicate reds, and neither bound has to be edited when a
    /// seam is added.
    private func assertScanReachedTheTree(
        _ declarations: [LogSeamDeclaration]
    ) throws {
        let bootstrap = try SourceScan.swiftSources(
            under: coreRoot.appendingPathComponent("App")
        )
        .filter {
            $0.lastPathComponent.hasPrefix("KiwiCore+Bootstrap")
        }
        var receivers: Set<String> = []
        for file in bootstrap {
            receivers.formUnion(
                SourceScan.allMatches(
                    in: SourceScan.stripComments(
                        try String(contentsOf: file, encoding: .utf8)
                    ),
                    pattern:
                        #"([A-Za-z_][A-Za-z0-9_.]*)\.onLog\s*="#
                )
            )
        }

        #expect(
            !receivers.isEmpty,
            Comment(
                rawValue: "no `.onLog =` assignment found in any "
                    + "KiwiCore+Bootstrap file under \(coreRoot) "
                    + "— the scan reached nothing, so nothing "
                    + "below was checked"
            )
        )
        #expect(
            declarations.count >= receivers.count,
            Comment(
                rawValue: "found \(declarations.count) `var "
                    + "onLog:` declaration(s) but bootstrap "
                    + "assigns \(receivers.count) distinct "
                    + "receiver(s). Each of those is declared "
                    + "somewhere, so this scan reached fewer "
                    + "files than it should have."
            )
        )
        #expect(
            declarations.contains { $0.owner == "KiwiCore" },
            Comment(
                rawValue: "the scan found no `var onLog:` in "
                    + "`KiwiCore` itself, so it did not reach "
                    + "`App/` — where the sink and every "
                    + "bootstrap file live"
            )
        )
    }
}
