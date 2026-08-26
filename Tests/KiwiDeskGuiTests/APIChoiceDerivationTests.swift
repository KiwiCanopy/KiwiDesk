import Foundation
import Testing

/// An enum argument's legal values are READ off the decoder,
/// never typed beside it (#1033).
///
/// The compiler enforces this today, because `APIChoice` has
/// exactly one initializer and it takes a metatype. That is not
/// something a reviewer would notice being undone: adding a
/// second, list-taking initializer is a two-line change that
/// compiles, reads harmlessly, and quietly reopens the drift
/// class #1033 was filed about — the CLI would then be free to
/// answer `top|bottom|left|right` while the decoder had grown a
/// fifth case.
///
/// So this scans the declaration rather than the behaviour. It
/// lives in the GUI test target because `SourceScan` does, and
/// it scans `Sources/KiwiDeskCore` (AGENTS.md: `SourceScan`
/// guards scan both trees).
@Suite("API choice derivation")
struct APIChoiceDerivationTests {
    static let recordFile =
        "Sources/KiwiDeskCore/Commands/Reference/APIRecord.swift"

    static var source: String {
        get throws {
            let root = SourceScan.repoRoot(from: #filePath)
            return try SourceScan.strippedSource(
                at: root.appendingPathComponent(recordFile)
            )
        }
    }

    @Test("APIChoice declares exactly one initializer")
    func oneInitializer() throws {
        let text = try Self.source
        guard
            let declaration = text.range(
                of: "public struct APIChoice"
            )
        else {
            Issue.record("APIChoice moved out of \(Self.recordFile)")
            return
        }
        let body = String(text[declaration.lowerBound...])
        // The struct is the file's last declaration bar the
        // protocol; count initializers to the end of it.
        let scope =
            body.range(of: "public protocol APIChoiceType")
            .map { String(body[..<$0.lowerBound]) } ?? body
        let one =
            "APIChoice must keep exactly one initializer — the "
            + "generic one that reads a decoder's cases. A "
            + "second one is how hand-typed values return."
        #expect(scope.occurrences(of: "init") == 1, "\(one)")
        let takesType =
            "the one initializer must take the TYPE, so the "
            + "values cannot be handed in"
        #expect(
            scope.contains(
                "init<T: APIChoiceType>(_ type: T.Type)"
            ),
            "\(takesType)"
        )
        #expect(
            scope.contains("T.allCases.map(\\.rawValue)"),
            "the values must be read off the type's own cases"
        )
    }

    @Test("no record file spells an enum's values by hand")
    func recordsBuildChoicesFromTypes() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let directory = root.appendingPathComponent(
            "Sources/KiwiDeskCore/Commands/Reference"
        )
        let files = try SourceScan.swiftSources(under: directory)
            .filter {
                $0.lastPathComponent.hasPrefix("APIRecords+")
            }
        // The FILTERED set, not the directory: a rename that
        // took the record files out of the `APIRecords+` family
        // would leave this loop iterating nothing and passing.
        #expect(
            files.count >= 8,
            "only \(files.count) record files reached the scan"
        )
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            let message =
                "\(file.lastPathComponent): build a choice with "
                + ".choice(name, Type.self), never by "
                + "constructing APIChoice beside the record"
            #expect(!text.contains("APIChoice("), "\(message)")
        }
    }
}
