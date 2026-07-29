import Foundation
import Testing

/// Every `var onLog:` declaration under `Sources/KiwiDeskCore`
/// defaults to `CoreLog.write` (#624).
///
/// `{ _ in }` is the
/// obvious thing to type when declaring a new seam, it compiles,
/// and the subsystem it silences is the one nobody was reading
/// yet — six of the eight seams carried exactly that default
/// until #624.
///
/// The argument for the default itself is on `CoreLog`, where an
/// author reaches it; the seam discovery is shared with
/// `LogSeamWiringTests` through `SourceScan.logSeamDeclarations`;
/// and `LogSeamSinkTests` owns the two invariants about the sink
/// itself (its body still writes, and Core never calls it).
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
            declarations.count > receivers.count,
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
            declarations.contains { $0.file.path.contains("/App/") },
            Comment(
                rawValue: "the scan found no `var onLog:` under "
                    + "`App/`, where the sink and every bootstrap "
                    + "file live, so it did not reach that "
                    + "directory"
            )
        )
    }
}
