import Foundation
import Testing

/// The family's one argument splitter and literal reader (#1899):
/// `labelSlotCount` and `firstArgument` both split through
/// `topLevelArguments`, so a comma inside any literal shape the
/// family knows must never split, and a nested call must stay
/// one argument.
@Suite("SourceScan argument splitter (#1899)")
struct SourceScanArgumentsTests {
    @Test("top-level commas split; nested ones do not")
    func splitsAtTopLevelOnly() {
        #expect(
            SourceScan.topLevelArguments(of: "a, f(b, c), [d, e]")
                == ["a", " f(b, c)", " [d, e]"]
        )
    }

    @Test("a comma inside any literal shape never splits")
    func literalCommasStayInside() {
        let plain = #""a, b", x"#
        let triple = "\"\"\"\na, b\n\"\"\", x"
        let raw = ##"#"a, "b""#, x"##
        for source in [plain, triple, raw] {
            let arguments = SourceScan.topLevelArguments(of: source)
            #expect(arguments.count == 2, "\(source): \(arguments)")
            #expect(arguments.last == " x", "\(source)")
        }
    }

    @Test("no argument text reads as one empty argument")
    func emptyIsOneArgument() {
        #expect(SourceScan.topLevelArguments(of: "") == [""])
        #expect(SourceScan.firstArgument(of: "") == "")
    }

    @Test("firstArgument is the first split, normalized")
    func firstArgumentIsTheFirstSplit() {
        #expect(
            SourceScan.firstArgument(of: "f(\n  a,\n  b\n), c")
                == "f( a, b )"
        )
    }

    @Test("a literal's value is its interior, in every shape")
    func literalValueIsTheInterior() {
        let cases: [(String, String)] = [
            (#""key.a""#, "key.a"),
            (#""a\"b""#, #"a\"b"#),
            ("\"\"\"\nx\n\"\"\"", "\nx\n"),
            (##"#"a"b"#"##, #"a"b"#),
        ]
        for (source, value) in cases {
            let text = Array(source)
            let read = SourceScan.literal(text, from: 0)
            #expect(read?.value == value, "\(source)")
            #expect(read?.end == text.count, "\(source)")
        }
        #expect(SourceScan.literal(Array("#if"), from: 0) == nil)
        #expect(SourceScan.literal(Array(#""open"#), from: 0) == nil)
    }
}
