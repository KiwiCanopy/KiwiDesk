import Foundation
import Testing

/// `CoreLog.write` is a default, not a logging API (#624).
///
/// Two invariants, split from `LogSeamDefaultTests` — which owns
/// "every seam names it" — because these two are about the sink
/// itself rather than about the seams, and the combined file was
/// closing on the 350-line ceiling.
///
/// 1. **Its body still writes.** Nothing else in the tree looks
///    at what `CoreLog.write` *does*: every other seam guard
///    assigns `core.onLog` itself, so none of them ever runs the
///    default. Gut the `NSLog` and the tree returns to its
///    pre-#624 behaviour with every seam still naming
///    `CoreLog.write` and every other guard green.
/// 2. **Core reaches it only through a seam declaration.** It is
///    `internal`, but internal is the whole of `KiwiDeskCore`. A
///    direct `CoreLog.write("…")` call site would put a
///    diagnostic in syslog that `KiwiCore.onLog` never sees —
///    the routing failure the wiring rule exists to prevent,
///    wearing a blessed-looking spelling.
@Suite("Log-seam sink")
struct LogSeamSinkTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
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
        let stripped = SourceScan.stripComments(source)
        // Uniqueness first. `range(of:)` takes the FIRST match,
        // so an overload declared above — `write(_:level:)` is
        // the obvious future one — would have its body read
        // instead, and a gutted `write` would pass. This also
        // turns a `balanced` failure into an honest red rather
        // than a nil that reports "no longer calls NSLog".
        // `guard`, not `#expect`: `#expect` does not
        // short-circuit, so letting the body assertions run on
        // the `nil` this returns fires a second, false red
        // ("no longer calls `NSLog`") beside the true one.
        guard
            stripped.components(separatedBy: "static func write")
                .count == 2
        else {
            Issue.record(
                Comment(
                    rawValue: "`CoreLog` declares `static func "
                        + "write` more than once (or not at "
                        + "all). This guard reads the first "
                        + "one's body, so an overload above the "
                        + "real default would be checked in its "
                        + "place."
                )
            )
            return
        }
        let body = try functionBody(
            of: "static func write",
            in: stripped
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
        let seams = try SourceScan.logSeamDeclarations(
            under: coreRoot
        )
        let declarationLines = Set(
            seams.map { "\($0.file.path):\($0.line)" }
        )
        let continuationLines = Set(
            seams.filter { $0.defaultValue == nil }
                .map { "\($0.file.path):\($0.line + 1)" }
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
                // A wrapped declaration puts its default on the
                // following line, which is not a call site.
                // Derived from the scan rather than by looking
                // at the previous line's text: only a
                // declaration whose default the scan could NOT
                // read continues onto the next line, so a
                // genuine call placed right after a complete
                // declaration is still caught — inspecting the
                // text skipped that, which is the single most
                // likely place to put one.
                guard
                    !continuationLines.contains(
                        "\(file.path):\(index + 1)"
                    )
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
}
