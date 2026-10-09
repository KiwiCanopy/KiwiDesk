import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The terminal half of `self_test` (#1889): a block per home and
/// a closing tally, rendered from the reply alone.
@Suite("CLI self_test rendering")
struct CLISelfTestRenderTests {
    private func row(
        _ name: String,
        _ home: String,
        _ verdict: String,
        _ detail: String
    ) -> JSONValue {
        .object([
            "name": .string(name),
            "kind": .string("symbol"),
            "home": .string(home),
            "verdict": .string(verdict),
            "detail": .string(detail),
        ])
    }

    @Test("rows group by home and the tally counts every label")
    func rendersBlocksAndTally() throws {
        let reply = JSONValue.object([
            "macos": .string("Version 28.0"),
            "counts": .object([
                "works": .number(1), "resolved": .number(0),
                "absent": .number(1), "failed": .number(0),
                "inconclusive": .number(0),
            ]),
            "probes": .array([
                row("SLSGetActiveSpace", "SkyLight", "works", "Space 1"),
                row("HideSpacesOperation", "WMBridge", "absent", "gone"),
            ]),
        ])
        let text = try #require(CLISelfTest.render(reply))
        let lines = text.components(separatedBy: "\n")
        #expect(lines.first == "macOS Version 28.0")
        #expect(lines.contains("SkyLight"))
        #expect(lines.contains("WMBridge"))
        let skyRow = try #require(
            lines.first { $0.contains("SLSGetActiveSpace") }
        )
        #expect(skyRow.hasPrefix("  works "))
        #expect(skyRow.hasSuffix("Space 1"))
        #expect(
            lines.last
                == "1 works, 0 resolved, 1 absent, 0 failed, "
                + "0 inconclusive"
        )
    }

    @Test("a reply of another shape is not rendered")
    func refusesOtherShapes() {
        #expect(CLISelfTest.render(.object([:])) == nil)
        #expect(
            CLISelfTest.render(
                .object(["probes": .array([.string("x")])])
            ) == nil
        )
    }

    @Test("only --json is an option")
    func options() {
        #expect(CLISelfTest.parseOptions([]) == false)
        #expect(CLISelfTest.parseOptions(["--json"]) == true)
        #expect(CLISelfTest.parseOptions(["--verbose"]) == nil)
        #expect(CLISelfTest.parseOptions(["--json", "x"]) == nil)
    }
}
