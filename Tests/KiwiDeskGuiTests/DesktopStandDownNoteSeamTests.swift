import Foundation
import Testing

/// The stand-down sentence keeps ONE home (#1336).
///
/// `DesktopAlreadyShownTests` pins that the payload and the log
/// AGREE at runtime, which is a weaker property than it reads: a
/// second, identical copy of the sentence inlined at the log
/// satisfies it, and nothing notices until someone later edits
/// one copy and the trace starts naming a different event than
/// the response (guard-prover round 2 — that mutation went
/// green).
///
/// So this pins the ROUTE rather than the text: each reader
/// names the constant. Retuning the sentence moves one line and
/// stays green, which is the calibration tests.md ▸ #1021 asks
/// for — a value pin here would red on every deliberate reword
/// and catch no regression.
@Suite("The stand-down sentence has one home (#1336)")
struct DesktopStandDownNoteSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    /// needle → the file that may carry it, exactly once.
    ///
    /// Two spellings because the readers sit at different
    /// depths: the response arm is inside the enum, the log line
    /// is in the `KiwiCore` extension beside it. Pinned by exact
    /// count in both directions — zero is an inlined literal
    /// (the escape above), two is a second reader that owes its
    /// own entry here.
    private static let readers: [(String, String)] = [
        ("Self.alreadyShownNote", "KiwiCore+DesktopSwitch.swift"),
        (
            "DesktopSwitchOutcome.alreadyShownNote",
            "KiwiCore+DesktopSwitch.swift"
        ),
    ]

    @Test("both readers name the constant, each exactly once")
    func bothReadersNameTheConstant() throws {
        for (needle, file) in Self.readers {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            #expect(
                sites.count == 1,
                .init(
                    rawValue: "\(needle) is expected exactly once, "
                        + "in \(file) — found "
                        + (sites.isEmpty
                            ? "none (an inlined literal?)"
                            : sites.map(\.site)
                                .joined(separator: ", "))
                )
            )
            #expect(
                sites.allSatisfy {
                    $0.file.lastPathComponent == file
                },
                .init(
                    rawValue: "\(needle) belongs in \(file) — found "
                        + sites.map(\.site).joined(separator: ", ")
                )
            )
        }
    }
}
