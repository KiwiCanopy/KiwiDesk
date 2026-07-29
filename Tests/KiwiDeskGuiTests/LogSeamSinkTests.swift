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

    /// Every immediate subdirectory of `Sources/KiwiDeskCore`
    /// contributed at least one scanned file.
    ///
    /// This guard needs a **wider** reach than the seam guards do,
    /// and that difference is not obvious. `LogSeamDefaultTests`
    /// carries the family's only floor, and it proves the walk
    /// reached every file holding a `var onLog:` — which is enough
    /// for a question about seams, and not enough for this one: a
    /// direct `CoreLog.write` can sit in any Core file at all.
    /// Narrowing the scan to skip a directory with no seam in it
    /// leaves every suite in the family green while the call-site
    /// ban quietly stops covering that subsystem. `Lua/` is such a
    /// directory, and dropping it was measured to pass all four.
    ///
    /// Derived from the filesystem, so a new subsystem is inside
    /// it on arrival and no list here is edited to keep it there.
    ///
    /// **The expected set must not come from the walker under
    /// test.** Deriving "directories holding a `.swift` file" via
    /// `SourceScan.swiftSources` would make this tautological —
    /// expected and actual narrow together and it is green
    /// forever. A second hand-rolled walk is the same trap one
    /// step out, and is the drift `tests.md` names for this
    /// helper family. A plain directory listing against the
    /// scan's own output is the only shape in which a narrowing
    /// is visible at all; do not "simplify" it into agreement.
    private func assertEverySubsystemWasScanned(
        _ scanned: [URL]
    ) throws {
        // Indexed, not searched: every scanned file descends
        // from `coreRoot`, so its depth is exact. Searching the
        // components for "KiwiDeskCore" would read the wrong
        // element on a checkout path that happens to contain one
        // higher up, and then red a correct tree.
        let depth = coreRoot.pathComponents.count
        let reached = Set(
            scanned.compactMap { file -> String? in
                let parts = file.pathComponents
                // `depth` is the subdirectory, `depth + 1` the
                // file inside it — so a `.swift` sitting directly
                // in `KiwiDeskCore/` contributes no directory,
                // which is correct.
                guard parts.count > depth + 1 else { return nil }
                return parts[depth]
            }
        )
        let directories = Set(
            try FileManager.default.contentsOfDirectory(
                at: coreRoot,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
            .filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey])
                    .isDirectory) == true
            }
            .map(\.lastPathComponent)
            // Assets, not code (AGENTS.md §1 owns that
            // classification), so it contributes no Swift file.
            // Checked both ways below, per the house rule for an
            // exemption list.
            .filter { $0 != "Resources" }
        )
        #expect(
            !reached.contains("Resources"),
            Comment(
                rawValue: "`Resources/` now holds Swift code, so "
                    + "its exemption here is stale — drop it and "
                    + "let the directory be covered like any "
                    + "other."
            )
        )
        #expect(
            directories.subtracting(reached).isEmpty,
            Comment(
                rawValue: "the scan reached no Swift file under "
                    + directories.subtracting(reached).sorted()
                    .joined(separator: ", ")
                    + ", so a direct `CoreLog` call there would "
                    + "go unseen — or the directory holds no "
                    + "Swift file yet. A narrowed file predicate does "
                    + "this, and the seam guards cannot catch it "
                    + "when the directory holds no seam."
            )
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
        let scanned = try SourceScan.swiftSources(under: coreRoot)
        try assertEverySubsystemWasScanned(scanned)

        var callSites: [String] = []
        for file in scanned
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
