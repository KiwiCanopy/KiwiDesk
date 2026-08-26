import Foundation
import Testing

@testable import KiwiDesk

/// The chord ladder's reach (#1016).
///
/// A source scan rather than a behaviour test, which is why it
/// is not in `OnboardingKeysTests` beside the chord assertions —
/// and splitting it is also what puts that file back under
/// AGENTS.md §2.1's ceiling, the two reasons agreeing.
@Suite("Onboarding chord ladder reach")
struct OnboardingChordReachTests {
    /// **The §2.1 split widened eight helpers, so this is the
    /// census that keeps the widening honest.**
    /// `OnboardingKeys+Chords.swift` exists because the file
    /// crossed the 350-line ceiling; Swift scopes `private` to
    /// the FILE, so the chord ladder had to become
    /// module-internal to be reachable from the enum's other
    /// half. That makes `rendered(combo:)` an app-wide second
    /// route to `ComboSymbols.render` — the packing the shortcuts
    /// panel and the recorder deliberately do differently — and
    /// the boundary was stated only in a doc comment, which is a
    /// state claim nothing enforces (`rule-authoring.md`).
    ///
    /// Derived, not hand-listed: it walks the GUI tree for
    /// anything naming `OnboardingKeys.` and asserts the callers
    /// are the three that should be — the wiring that builds the
    /// families, the view that draws them, and the enum's own
    /// second half. A ninth helper needs no edit here; a NEW
    /// caller does, consciously.
    @Test("the chord ladder is reached only from its own tree")
    func chordHelpersStayInternal() throws {
        let tree = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let callers = try SourceScan.swiftSources(under: tree)
            .filter { file in
                let text = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                // BOTH routes. A dotted call is one way in; an
                // `extension OnboardingKeys` is the other, and it
                // reaches every module-internal helper without
                // naming the enum once (`guard-prover`,
                // 2026-08-26) — which is exactly how `+Chords`
                // itself reaches them.
                return text.contains("OnboardingKeys.")
                    || text.contains("extension OnboardingKeys")
            }
            .map { $0.lastPathComponent }
            .sorted()
        #expect(
            callers == [
                "AppDelegate+Onboarding.swift",
                "OnboardingKeys+Chords.swift",
                "OnboardingView+Keys.swift",
            ],
            Comment(
                rawValue:
                    "OnboardingKeys is reached from \(callers); "
                    + "its helpers are module-internal only "
                    + "because §2.1 split the file, and a caller "
                    + "outside its own tree is a second route to "
                    + "ComboSymbols with different packing"
            )
        )
    }
}
