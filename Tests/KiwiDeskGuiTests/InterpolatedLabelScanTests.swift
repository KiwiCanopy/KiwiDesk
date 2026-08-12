import Foundation
import Testing

@testable import KiwiDesk

/// The discovery half of `InterpolatedLabelTests` (#818) — held
/// apart because it guards the SCANNER rather than the register,
/// and because that suite reached the 350-line ceiling.
///
/// `SourceScan.destinationTitleKeys` feeds a **fail-open** scan.
/// A destination case it cannot resolve raises nothing; it just
/// leaves every frame naming that destination undiscovered, and
/// therefore unfloored. An EMPTY parse would red loudly, because
/// `conversionsHold` would then find eight registered frames
/// interpolating nothing — but a PARTIAL parse reds on nothing
/// at all, which is exactly what shipped: the first cut matched
/// per line, and `.advancedColors` is the one case whose `L(`
/// and key literal sit on different lines. The frame naming it
/// silently lost a label, and the register's own equality check
/// passed at the wrong number.
///
/// So the parser is held against the ENUM rather than against a
/// count — `rule-authoring.md` ▸ "a guard over generated output
/// asserts its input" applied to a parser's output.
@Suite("Destination titles resolve for the label scan")
struct InterpolatedLabelScanTests {
    @Test("every destination case resolves to its key")
    func destinationParserIsComplete() throws {
        let pairs = try SourceScan.destinationTitleKeys()
        #expect(
            !pairs.isEmpty,
            "the destination parser resolved nothing at all"
        )
        for destination in SettingsDestination.allCases {
            let name = String(describing: destination)
            #expect(
                pairs[name] != nil,
                """
                SettingsDestination.\(name) did not resolve to a \
                destination.* key. Frames naming it through \
                `.title` are invisible to the scan and carry no \
                floor — fix the parser, not the register.
                """
            )
        }
    }
}
