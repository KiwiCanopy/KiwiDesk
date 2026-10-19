import Foundation
import Testing

/// Every on/off in this tree is a leading checkbox, never a switch
/// (#2439; design-decisions ▸ "Wide controls share the label axis;
/// compact ones trail").
@Suite("Toggle style convention")
struct ToggleStyleConventionTests {
    /// Files that may draw a switch, and why. The one copy of who
    /// may; empty by ruling.
    private static let allowed: [String: String] = [:]

    @Test("no switch-style toggle in the GUI tree")
    func noSwitchToggles() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var found: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .filter { !$0.isWhitespace }
            scanned += 1
            let needles = [
                ".toggleStyle(.switch)",
                "SwitchToggleStyle(",
            ]
            if needles.contains(where: source.contains) {
                found.append(file.lastPathComponent)
            }
        }
        #expect(scanned > 100)
        #expect(
            Set(found) == Set(Self.allowed.keys),
            Comment(
                rawValue:
                    "switch-style toggles in \(found): an on/off "
                    + "is a leading checkbox (#2439)"
            )
        )
    }
}
