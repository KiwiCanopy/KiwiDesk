import Foundation
import Testing

/// An enum argument's legal values are READ off the decoder,
/// never typed beside it (#1033).
///
/// The compiler carries most of this: `APIChoice` keeps its
/// storage `private`, so an initializer in any other file could
/// not set it and would not compile. What the compiler cannot
/// see is a second initializer added *in that file*, which is
/// exactly what a `guard-prover` round used to defeat the first
/// version of this suite — it appended an extension after the
/// protocol declaration, outside the slice the scan was reading,
/// and shipped `diag` as a legal `AppBarEdge` with all 33 tests
/// green.
///
/// So the scan reads the WHOLE of `APIChoice.swift` rather than
/// a slice of a larger file, which is why that type has a file
/// to itself. The question "how many initializers are there"
/// then has a total answer.
@Suite("API choice derivation")
struct APIChoiceDerivationTests {
    static let choiceFile =
        "Sources/KiwiDeskCore/Commands/Reference/APIChoice.swift"

    static let recordDirectory =
        "Sources/KiwiDeskCore/Commands/Reference"

    static func source(_ path: String) throws -> String {
        let root = SourceScan.repoRoot(from: #filePath)
        return try SourceScan.strippedSource(
            at: root.appendingPathComponent(path)
        )
    }

    @Test("APIChoice declares exactly one initializer")
    func oneInitializer() throws {
        let text = try Self.source(Self.choiceFile)
        let owned =
            "APIChoice moved out of its own file; this scan is "
            + "only total while it has one"
        #expect(text.contains("public struct APIChoice"), "\(owned)")
        // The whole file, not a slice: an extension anywhere in
        // it — before or after the protocol — is counted.
        let one =
            "APIChoice must keep exactly one initializer — the "
            + "generic one that reads a decoder's cases. A "
            + "second one is how hand-typed values return, and "
            + "it compiles."
        #expect(text.occurrences(of: "init") == 1, "\(one)")
        let takesType =
            "the one initializer must take a METATYPE, so the "
            + "values cannot be handed in"
        #expect(
            text.contains("init<T: APIChoiceType>(_ type: T.Type)"),
            "\(takesType)"
        )
        #expect(
            text.contains("T.allCases.map(\\.rawValue)"),
            "the values must be read off the type's own cases"
        )
        // The storage is what makes an initializer in another
        // file impossible. Without it the count above is the
        // only thing standing.
        let stored =
            "APIChoice's storage must stay private, or another "
            + "file can write a second initializer"
        #expect(text.contains("private let derived"), "\(stored)")
    }

    @Test("every choice argument names a type, not a list")
    func choicesNameTheirType() throws {
        // The call-site half, and the one that states the
        // invariant directly: `.choice(name, X.self)`. A
        // `values:`-taking factory added beside `APIArgument`
        // would keep `APIChoice(` out of the record files
        // entirely, which is how the prover's mutation hid.
        let root = SourceScan.repoRoot(from: #filePath)
        let directory = root.appendingPathComponent(
            Self.recordDirectory
        )
        let files = try SourceScan.swiftSources(under: directory)
            .filter {
                $0.lastPathComponent.hasPrefix("APIRecords+")
            }
        // The FILTERED set: a rename taking the record files out
        // of the `APIRecords+` family would otherwise leave this
        // iterating nothing and passing.
        #expect(
            files.count >= 8,
            "only \(files.count) record files reached the scan"
        )
        var seen = 0
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            let message =
                "\(file.lastPathComponent): build a choice with "
                + ".choice(name, Type.self), never by "
                + "constructing APIChoice beside the record"
            #expect(!text.contains("APIChoice("), "\(message)")
            for argument in Self.choiceArguments(in: text) {
                seen += 1
                let call =
                    "\(file.lastPathComponent): .choice(…, "
                    + "\(argument)) must name a Swift type — a "
                    + "list of values is the drift #1033 removed"
                #expect(argument.hasSuffix(".self"), "\(call)")
            }
        }
        let reach =
            "only \(seen) choice call sites found; the scan is "
            + "not reading the records"
        #expect(seen >= 15, "\(reach)")
    }

    /// The second argument of each `.choice(` call — everything
    /// between the first comma and the matching close paren,
    /// trimmed, with a trailing `optional:` clause dropped.
    static func choiceArguments(in text: String) -> [String] {
        var found: [String] = []
        var cursor = text.startIndex
        while let call = text.range(
            of: ".choice(",
            range: cursor..<text.endIndex
        ) {
            cursor = call.upperBound
            guard
                let close = text[cursor...].firstIndex(of: ")")
            else { break }
            let inside = text[cursor..<close]
            let parts = inside.split(separator: ",")
            guard parts.count >= 2 else { continue }
            let second = parts[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            found.append(second)
        }
        return found
    }
}
