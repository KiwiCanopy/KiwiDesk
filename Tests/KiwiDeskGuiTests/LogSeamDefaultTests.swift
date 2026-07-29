import Foundation
import Testing

/// Every `var onLog:` declaration under `Sources/KiwiDeskCore`
/// defaults to `CoreLog.write` (#624).
///
/// `{ _ in }` is the obvious thing to type when declaring a new
/// seam, it compiles,
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
    /// **Distinct receivers, and strictly greater.** Deduping
    /// the receivers is what absorbs a seam assigned twice — the
    /// duplicate that `#625` is about, and the shape a stale
    /// auto-merge produces. Keeping `>` is what still catches a
    /// narrowed scan: drop one subsystem from the walk and both
    /// sides fall by one together, so `>=` would hold and the
    /// seam would go unchecked by either guard. That is the
    /// `tests.md` harm exactly, so the strict bound stays.
    ///
    /// What it is **not**: a law that declarations always exceed
    /// receivers. A receiver is not declared — its *type* is — so
    /// wiring N instances of one seam-owning type gives N
    /// receivers against one declaration, and the margin here
    /// absorbs none of them. That shape (`LogSeamWiringTests`
    /// documents it as plausible, nothing has it today) would red
    /// naming a scan bug that is not there. It fails shut, and
    /// the alternative reopens a live hole.
    ///
    /// **And an anchor in `App/`.** The count alone still passes
    /// a scan narrowed to skip `App/` entirely, which drops the
    /// bootstrap files and the sink together and so shrinks both
    /// sides at once. Anchoring on the *directory* rather than on
    /// the sink's type name pins the same thing without a second
    /// copy of who the sink is, and survives renaming it.
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
