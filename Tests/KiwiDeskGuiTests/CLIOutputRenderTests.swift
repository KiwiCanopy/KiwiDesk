import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// How the CLI prints a command response's payload (#1034).
///
/// Two facets, deliberately separated: key ORDER must not depend
/// on where the process's dictionary hashing landed, and only the
/// terminal gets the indented form. The first is unconditional,
/// the second is the caller's decision — so a piped call keeps
/// the exact single line existing scripts already parse.
@Suite("CLI JSON output shape (#1034)")
struct CLIOutputRenderTests {
    /// An object whose insertion order is deliberately NOT
    /// alphabetical: the `list_monitors` shape from the report.
    private var monitor: JSONValue {
        .object([
            "name": .string("DELL U2720Q"),
            "width": .number(2560),
            "fingerprint": .string("DELL U2720Q:2560x1440"),
            "height": .number(1440),
            "id": .number(3),
        ])
    }

    @Test("keys are sorted whether or not output is pretty")
    func keysSortInBothModes() {
        // The bug was two SIBLING objects in one response
        // disagreeing on key order, so pinning one rendering
        // against itself would prove nothing — pin the order
        // against the alphabet, which is the only stable thing
        // a reader or a diff can rely on.
        for pretty in [false, true] {
            let text = CLIOutput.render(monitor, pretty: pretty)
            let rendered = try! #require(text)
            let keys = ["fingerprint", "height", "id", "name", "width"]
            var searchFrom = rendered.startIndex
            for key in keys {
                let found = rendered.range(
                    of: "\"\(key)\"",
                    range: searchFrom..<rendered.endIndex
                )
                #expect(
                    found != nil,
                    "\(key) missing (pretty: \(pretty))"
                )
                guard let found else { break }
                searchFrom = found.upperBound
            }
        }
    }

    @Test("a piped call stays on one line")
    func compactIsSingleLine() {
        // The contract for scripts: no newline anywhere inside
        // the payload, however nested it is.
        let nested = JSONValue.array([monitor, monitor])
        let text = try! #require(
            CLIOutput.render(nested, pretty: false)
        )
        #expect(!text.contains("\n"))
    }

    @Test("a terminal gets one element per line")
    func prettyBreaksLines() {
        // 262 names on one 6.9 KB line was the reported symptom;
        // the fix is that a multi-element payload occupies more
        // lines than it has elements' worth of braces.
        let names = JSONValue.array(
            ["focus", "swap", "resize"].map { .string($0) }
        )
        let text = try! #require(
            CLIOutput.render(names, pretty: true)
        )
        #expect(text.split(separator: "\n").count >= 3)
    }

    @Test("the two modes differ only in whitespace")
    func modesAgreeOnContent() {
        // Pretty-printing must not add, drop or reorder a thing
        // — otherwise a user reading the terminal is reading a
        // different response than their script parsed.
        let payload = JSONValue.array([monitor, .null, .bool(true)])
        let compact = try! #require(
            CLIOutput.render(payload, pretty: false)
        )
        let pretty = try! #require(
            CLIOutput.render(payload, pretty: true)
        )
        let stripped = pretty.filter { !$0.isWhitespace }
        #expect(stripped == compact.filter { !$0.isWhitespace })
    }
}
