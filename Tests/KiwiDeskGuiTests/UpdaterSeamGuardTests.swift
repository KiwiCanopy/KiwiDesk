import Foundation
import Testing

/// The updater seam's construction sites (#874).
///
/// Split out of `MachineTouchTests` at §2.1's ceiling rather than
/// merged into it — same family, same idiom, its own file, which
/// `.claude/rules/tests.md` asks for before the ceiling rather
/// than after.
@Suite("Updater seam stays singular (#874)")
struct UpdaterSeamGuardTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let productionTrees = [
        root.appendingPathComponent("Sources/KiwiDeskCore"),
        root.appendingPathComponent("Sources/KiwiDesk"),
    ]

    private static func sites(
        of needle: String,
        under trees: [URL]
    ) throws -> [MachineTouchSite] {
        try trees.flatMap {
            try SourceScan.identifierSites(of: needle, under: $0)
        }
    }

    /// The updater seam (#874). Two needles, each pinned by
    /// EXACT COUNT rather than by "no strays", because this seam
    /// fails in both directions and only one of them is visible.
    ///
    /// A second `SparkleUpdater()` is a second Sparkle scheduled
    /// against one app. But the dangerous direction is ZERO:
    /// delete the one wiring line and the menu row greys —
    /// visible — while the scheduled background channel never
    /// starts, which is not. An app whose update path silently
    /// never runs is what `docs/design-decisions.md` ▸ *No
    /// distribution channel without an update path* calls the
    /// unrecoverable failure, and nothing else in this tree
    /// would red.
    private static let updaterAllowed = "AppUpdater.swift"
    private static let updaterWiring = "AppDelegate.swift"

    @Test("the live updater is built once, in one place")
    func updaterBuiltOnce() throws {
        // The Sparkle controller itself: constructed only inside
        // the seam's live conformer. The needle carries the open
        // paren so it matches the CONSTRUCTION and not the
        // stored property's type annotation one line above it —
        // without it this counts two and reads as a duplicate.
        let controllers = try Self.sites(
            of: "SPUStandardUpdaterController(",
            under: Self.productionTrees
        )
        #expect(
            controllers.count == 1,
            """
            expected exactly one SPUStandardUpdaterController \
            construction, found \(controllers.count): \
            \(controllers.map(\.site).joined(separator: ", "))
            """
        )
        #expect(
            controllers.allSatisfy {
                $0.file.lastPathComponent == Self.updaterAllowed
            }
        )

        // The wiring: `AppUpdaterFactory.make()` is called once,
        // from AppDelegate. Zero means the app ships without an
        // update channel and greys one menu row to say so.
        let wirings = try Self.sites(
            of: "AppUpdaterFactory.make",
            under: Self.productionTrees
        )
        #expect(
            wirings.count == 1,
            """
            expected exactly one AppUpdaterFactory.make() call, \
            found \(wirings.count). Zero means the update \
            channel never starts: \
            \(wirings.map(\.site).joined(separator: ", "))
            """
        )
        #expect(
            wirings.allSatisfy {
                $0.file.lastPathComponent == Self.updaterWiring
            }
        )
    }
}
