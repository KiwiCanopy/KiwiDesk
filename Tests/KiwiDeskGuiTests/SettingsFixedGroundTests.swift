import Foundation
import Testing

@testable import KiwiDesk

/// The raw-colour lens's fixed-ground arm, split from
/// `SettingsRawColorTests` at the §2.1 ceiling.
///
/// Chrome that is dark in BOTH modes: the ambient-derived
/// hierarchical greys land near-white or near-black by the
/// WINDOW's appearance while the ground never moves, so on
/// these families they are banned outright — on mode-varying
/// surfaces they self-invert and gui.md's "prefer a concrete
/// ink" stays a preference. Membership is STEM-derived, not a
/// file list — the §2.1 ceiling keeps splitting exactly these
/// families (`HomeCardPlate+X`, `SettingsFooter+Y`), and a
/// hand list let the next split land outside the ban silently
/// (architect review 2026-08-10; the dark-pass branch split
/// `+SpacesTile` off and had to remember the entry).
@Suite("Settings fixed-ground greys")
struct SettingsFixedGroundTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static var settingsDir: URL {
        root.appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    private let fixedGroundStems = [
        "SettingsFooter", "HomeCardPlate", "KeyboardBoard",
        "KeyboardChrome",
    ]

    @Test("no hierarchical grey on a fixed-dark ground")
    func fixedGroundsBanHierarchicalGreys() throws {
        let needles = [
            ".secondary", ".tertiary", ".quaternary",
        ]
        var matched: [String: Int] = [:]
        for file in try swiftFiles(under: Self.settingsDir) {
            let name = file.lastPathComponent
            guard
                let stem = fixedGroundStems.first(where: {
                    name == "\($0).swift"
                        || name.hasPrefix("\($0)+")
                })
            else { continue }
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            matched[stem, default: 0] += 1
            for needle in needles {
                #expect(
                    !source.contains(needle),
                    Comment(
                        rawValue:
                            "\(name) draws \(needle) on "
                            + "fixed-dark chrome"
                    )
                )
            }
        }
        // PER STEM, not an aggregate floor: a hand-restated
        // total let a renamed-away one-file family hide behind
        // another family's growth (re-review 2026-08-10, the
        // rule-authoring "derive the number" clause).
        for stem in fixedGroundStems {
            #expect(
                matched[stem, default: 0] >= 1,
                Comment(
                    rawValue:
                        "stem \(stem) matched no file — "
                        + "renamed family, update the stem"
                )
            )
        }
    }

    private func swiftFiles(under dir: URL) throws -> [URL] {
        var result: [URL] = []
        let walker = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: nil
        )
        while let next = walker?.nextObject() as? URL {
            if next.pathExtension == "swift" {
                result.append(next)
            }
        }
        return result
    }
}
