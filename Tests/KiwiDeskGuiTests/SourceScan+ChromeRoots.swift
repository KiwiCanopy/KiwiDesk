import Foundation

/// Which GUI trees draw the app's own chrome — the one list every
/// tint-following guard scans.
///
/// **Why one list.** Five suites hand-listed "Settings +
/// Onboarding" independently (#828): the raw-colour lens, the
/// placement-rule scan, the bordered seal, label neutrality and
/// the button-style convention. A sixth tree would have to join
/// five registers to be covered, and a tree missing from one of
/// them is not partly covered — it is silently exempt from a
/// fail-open guard, which is the `SettingsCatalogFiles` admission
/// ground in `.claude/rules/tests.md` exactly.
///
/// **What belongs here.** A directory under `Sources/KiwiDesk`
/// that draws chrome the app owns: surfaces, inks, borders,
/// buttons that take the window tint. Not a tree that merely
/// contains views — the test of membership is whether a raw
/// colour or an unstyled button there would ship a defect the
/// tint makes visible.
///
/// Guards that scan a NARROWER set still say so themselves —
/// `LayoutSchematicPlacementScanTests` watches the two trees that
/// draw schematics, which is a different question from chrome.
enum ChromeScanRoots {
    /// The trees, as repo-relative paths.
    ///
    /// Onboarding joined when #828 tinted the tour: every button
    /// there had no `.buttonStyle` at all, which is harmless
    /// until a window takes an accent and then is #759 in the
    /// first window every user sees.
    static let paths = [
        "Sources/KiwiDesk/Settings",
        "Sources/KiwiDesk/Onboarding",
    ]

    static func urls(from filePath: String) -> [URL] {
        let repo = SourceScan.repoRoot(from: filePath)
        return paths.map { repo.appendingPathComponent($0) }
    }

    /// Every Swift file under every root.
    static func sources(from filePath: String) throws -> [URL] {
        try urls(from: filePath).flatMap {
            try SourceScan.swiftSources(under: $0)
        }
    }
}
