import Foundation
import Testing

/// Every `var onLog` declaration under `Sources/KiwiDeskCore`
/// defaults to `CoreLog.emit` (#624).
///
/// The argument for that default is on `CoreLog` itself, where an
/// author reaches it. What this guard adds is that the default
/// cannot drift back one seam at a time: `{ _ in }` is the
/// obvious thing to type when declaring a new seam, it compiles,
/// and the subsystem it silences is the one nobody was reading
/// yet. Six of the eight seams carried exactly that default
/// until #624.
///
/// It is the **companion** to `LogSeamWiringTests`, not a
/// duplicate of it, and the two fail on opposite mistakes: that
/// one catches a seam nobody wired, this one catches a seam whose
/// unwired state would be silent. Neither implies the other — a
/// seam can be wired and still declare a no-op default (harmless
/// today, a silent drop the moment someone forgets the wiring),
/// and a seam can default here and never be wired (loud, but
/// bypassing the sink a GUI console reads from).
///
/// Deliberately line-scoped: it reads the default off the same
/// line as the declaration and **gaps** — reds naming what it
/// could not read — on a declaration whose `=` is not there. A
/// wrapped or otherwise unrecognised shape therefore fails shut
/// with an honest message rather than as "does not default to
/// `CoreLog.emit`", which would send the reader looking at the
/// wrong thing.
///
/// It lives in the GUI test target because `SourceScan` does, as
/// `LogSeamWiringTests` and `VisibleBoundsRoutingTests` do.
@Suite("Log-seam defaults")
struct LogSeamDefaultTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    @Test("Every onLog seam defaults to CoreLog.emit")
    func everySeamDefaultsToTheSyslogWrite() throws {
        let declarations = try onLogDeclarations()

        // The canary over the collection this test consumes.
        // `SourceScan.swiftSources` answers `[]` for a directory
        // that does not exist rather than throwing, so a mistyped
        // `coreRoot` yields no declarations and every loop below
        // passes without asserting once. No count is pinned: the
        // set is meant to grow, and a hand-written total would
        // red on the next honest seam.
        #expect(
            !declarations.isEmpty,
            Comment(
                rawValue: "no `var onLog` declaration found "
                    + "under \(coreRoot) — the scan reached "
                    + "nothing, so nothing below was checked"
            )
        )

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
                defaultValue == "CoreLog.emit",
                Comment(
                    rawValue: "\(declaration.site) defaults its "
                        + "`onLog` seam to `\(defaultValue)`. "
                        + "Every seam defaults to `CoreLog.emit` "
                        + "so that forgetting to wire one costs "
                        + "a routing inconsistency rather than "
                        + "silence — see `CoreLog`."
                )
            )
        }
    }

    // MARK: - Discovery

    private struct Declaration {
        /// `File.swift:12`, for a message that can be clicked.
        let site: String
        /// The text right of `=`, or nil when the line has none.
        let defaultValue: String?
    }

    /// Every `var onLog:` declaration and the default it carries.
    ///
    /// The colon is load-bearing exactly as it is in
    /// `LogSeamWiringTests`: without it a future `onLogLevel`
    /// registers as a seam and is asked for a default it has no
    /// use for.
    private func onLogDeclarations() throws -> [Declaration] {
        var found: [Declaration] = []
        for file in try SourceScan.swiftSources(under: coreRoot) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let lines = source.split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            for index in lines.indices
            where lines[index].contains("var onLog:") {
                found.append(
                    Declaration(
                        site: "\(file.lastPathComponent):"
                            + "\(index + 1)",
                        defaultValue: defaultValue(
                            on: lines[index]
                        )
                    )
                )
            }
        }
        return found
    }

    /// The trimmed text after the first `=`, or nil when the
    /// line carries none. `(String) -> Void` holds no `=`, so
    /// the first one is the assignment's.
    private func defaultValue(on line: Substring) -> String? {
        guard let equals = line.firstIndex(of: "=") else {
            return nil
        }
        let value = line[line.index(after: equals)...]
            .trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
