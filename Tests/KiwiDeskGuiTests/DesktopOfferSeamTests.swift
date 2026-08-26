import Foundation
import Testing

/// Every surface that draws or names a macOS **Desktop** row
/// widens its Desktop list through the one union,
/// `KeybindingCatalog.offeredDesktops` — the register of who
/// consumes it, by exact count.
///
/// Why a scan rather than a type. The union is what keeps a
/// bound Desktop row alive when its screen is unplugged, and a
/// surface that forgets it does not break: it simply stops
/// offering that row, silently, on a machine the developer is
/// not sitting at. `guard-prover` proved that exact shape
/// against the panel on 2026-08-26 — deleting the call at
/// `ShortcutsReference.build` left all 86 shortcut tests green,
/// because the fixture bound a Desktop that happened to be live.
/// The behavioural suites are stronger now, but they can only
/// cover a call site that EXISTS; nothing else notices a fifth
/// surface that never joined.
///
/// **The lens, not the list** (`WMBridgeSeamTests`): exact
/// per-file counts, so an unlisted consumer fails on arrival and
/// a removed listed one fails too.
///
/// Comments are stripped before matching, so the two files that
/// merely CITE the union in prose — `OrphanedShortcuts`, which
/// explains why the Space net deliberately does not use it, and
/// `ShortcutsFamilyRows` — are correctly absent from the map. A
/// citation is not a consumer.
@Suite("Desktop offer seam")
struct DesktopOfferSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private var sourceRoots: [URL] {
        SourceScan.targetTrees(
            under: Self.root.appendingPathComponent("Sources")
        )
    }

    /// Every file that spells the union today, and how often.
    /// The first entry is the declaration itself; the rest are
    /// the four surfaces, by role — the editor's rows, the ⌃⌥K
    /// panel's bands, the unsaved-changes readout, and the
    /// conflict banner's label roster. The last of those is the
    /// one this guard was written after: it shipped without the
    /// union and narrated raw English inside a localized
    /// sentence, which is #96's defect.
    private let allowed: [String: Int] = [
        "KiwiDesk/Settings/Components/Keybindings/"
            + "KeybindingCatalog+Desktops.swift": 1,
        "KiwiDesk/Settings/Components/Keybindings/"
            + "KeybindingCatalog+DisplayName.swift": 1,
        "KiwiDesk/Settings/Sections/ShortcutsSection.swift": 1,
        "KiwiDesk/Settings/"
            + "SettingsValueReadout+ShortcutsGlyphs.swift": 1,
        "KiwiDesk/Shortcuts/ShortcutsReference.swift": 1,
    ]

    @Test("every Desktop-row surface widens through the union")
    func consumersArePinned() throws {
        let needle = "offeredDesktops("
        var counts: [String: Int] = [:]
        for root in sourceRoots {
            let prefix = root.deletingLastPathComponent().path + "/"
            for file in try SourceScan.swiftSources(under: root) {
                let source = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                let hits = source.occurrences(of: needle)
                guard hits > 0 else { continue }
                counts[
                    String(file.path.dropFirst(prefix.count))
                ] = hits
            }
        }
        // Non-vacuous: the scan must have found the declaration,
        // or the needle stopped matching and every count below
        // is zero against zero.
        #expect(counts.count == allowed.count)
        for (path, found) in counts.sorted(by: { $0.key < $1.key }) {
            #expect(
                allowed[path] == found,
                """
                \(path) spells `\(needle)` \(found)x, allowed \
                \(allowed[path].map(String.init) ?? "0"). A \
                surface drawing or naming a Desktop row widens \
                its list through the union, or it silently \
                stops offering a row whose screen is unplugged.
                """
            )
        }
        for (path, count) in allowed where counts[path] == nil {
            #expect(
                count == 0,
                """
                \(path) no longer spells `\(needle)` — either it \
                stopped widening, or it is gone; drop its entry \
                so the guard keeps biting.
                """
            )
        }
    }
}
