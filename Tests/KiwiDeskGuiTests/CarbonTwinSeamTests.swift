import Foundation
import Testing

/// A menu row drawing a Carbon-bound chord asks the one
/// `KeyCombo.isCarbonTwin` whether to drop its keyDown (#2869,
/// input-and-animation.md): the bar menus and the status item each
/// once carried a check of their own, and the two drifted. Scans
/// both Sources trees, comments stripped, so a spelling in prose
/// counts nothing; a call split as `.isPressed (by:` would pass.
@Suite("Carbon twin seam")
struct CarbonTwinSeamTests {
    /// Every `isCarbonTwin(` call site, by file, and how many.
    private static let twinCallers = [
        "BarMenu.swift": 1,
        "StatusItemController+Menu.swift": 2,
    ]

    private func counts(of needle: String) throws -> [String: Int] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        let walker = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        )
        var scanned = 0
        var found: [String: Int] = [:]
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            scanned += 1
            let text = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            let hits = text.components(separatedBy: needle).count - 1
            if hits > 0 { found[url.lastPathComponent] = hits }
        }
        #expect(scanned > 100, "the scan read the Sources trees")
        return found
    }

    @Test("only the twin check reads a chord's press")
    func pressHasOneReader() throws {
        #expect(
            try counts(of: ".isPressed(by:")
                == ["KeyCombo+MenuEquivalent.swift": 1]
        )
    }

    @Test("every menu row's drop asks the twin check")
    func callersAreNamed() throws {
        var callers = try counts(of: "isCarbonTwin(")
        // The declaration itself.
        callers["KeyCombo+MenuEquivalent.swift", default: 0] -= 1
        callers = callers.filter { $0.value != 0 }
        #expect(callers == Self.twinCallers)
    }
}
