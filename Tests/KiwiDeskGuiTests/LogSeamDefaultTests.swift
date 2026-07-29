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
        let body = SourceScan.stripComments(source)
            .components(separatedBy: "static func write(")
        #expect(
            body.count == 2,
            Comment(
                rawValue: "CoreLog no longer declares `static "
                    + "func write(` — this guard reads its body "
                    + "and cannot find it"
            )
        )
        #expect(
            body.last?.contains("NSLog(") == true,
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
            body.last?.contains("#if") != true,
            Comment(
                rawValue: "`CoreLog.write`'s body is "
                    + "conditionally compiled — a build where "
                    + "the write vanishes is the failure this "
                    + "guard exists to catch"
            )
        )
    }

    @Test("Core reaches CoreLog only through a seam default")
    func theDefaultIsNeverCalledDirectly() throws {
        let declarationLines = Set(
            try SourceScan.logSeamDeclarations(under: coreRoot)
                .map(\.site)
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
                let site = "\(file.lastPathComponent):\(index + 1)"
                guard !declarationLines.contains(site) else {
                    continue
                }
                callSites.append(site)
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
    /// The floor is **derived, not restated**: the seams outnumber
    /// bootstrap's assignments, because `KiwiCore.onLog` is a
    /// declaration that is never assigned. So a scan that lost even
    /// one declaration reds here, and the bound moves on its own
    /// when a seam is added. A hand-written total would instead red
    /// on the next honest seam, and `!isEmpty` would be satisfied
    /// by a single surviving declaration while eight went
    /// unchecked.
    private func assertScanReachedTheTree(
        _ declarations: [LogSeamDeclaration]
    ) throws {
        let bootstrap = try SourceScan.swiftSources(
            under: coreRoot.appendingPathComponent("App")
        )
        .filter {
            $0.lastPathComponent.hasPrefix("KiwiCore+Bootstrap")
        }
        var assignments = 0
        for file in bootstrap {
            assignments +=
                SourceScan.allMatches(
                    in: SourceScan.stripComments(
                        try String(contentsOf: file, encoding: .utf8)
                    ),
                    pattern: #"(\.onLog)\s*="#
                ).count
        }

        #expect(
            assignments > 0,
            Comment(
                rawValue: "no `.onLog =` assignment found in any "
                    + "KiwiCore+Bootstrap file under \(coreRoot) "
                    + "— the scan reached nothing, so nothing "
                    + "below was checked"
            )
        )
        #expect(
            declarations.count > assignments,
            Comment(
                rawValue: "found \(declarations.count) `var "
                    + "onLog:` declaration(s) but \(assignments) "
                    + "bootstrap assignment(s). Every seam that "
                    + "is assigned must first be declared, and "
                    + "`KiwiCore.onLog` is declared without "
                    + "being assigned, so declarations always "
                    + "exceed assignments — this scan lost some."
            )
        )
    }
}
