import Foundation
import Testing

/// The updater seam's construction sites (#874), and the one
/// override that keeps its prompt visible (#1011).
///
/// Its own file rather than a section of `MachineTouchTests`,
/// which was already at §2.1's ceiling — same family and the
/// same needle idiom, split before crossing rather than after.
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

    /// The updater seam (#874). Every needle pinned by EXACT
    /// COUNT rather than by "no strays", because this seam fails
    /// in both directions and only one of them is visible.
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
        // Sparkle's own two objects: constructed only inside
        // the seam's live conformer. Each needle carries the
        // open paren so it matches the CONSTRUCTION and not a
        // stored property's type annotation a line above it —
        // without it this counts two and reads as a duplicate.
        //
        // Two needles rather than one because #1011 split what
        // `SPUStandardUpdaterController` used to hold: the
        // updater, and the user driver it shows its UI through.
        // A second `SPUUpdater` is a second scheduler; a second
        // `UpdatePromptDriver` is a driver nothing is wired to.
        for needle in ["SPUUpdater(", "UpdatePromptDriver("] {
            let built = try Self.sites(
                of: needle,
                under: Self.productionTrees
            )
            #expect(
                built.count == 1,
                """
                expected exactly one \(needle) construction, \
                found \(built.count): \
                \(built.map(\.site).joined(separator: ", "))
                """
            )
            #expect(
                built.allSatisfy {
                    $0.file.lastPathComponent
                        == Self.updaterAllowed
                }
            )
        }

        // The live conformer itself. This needle is the one
        // the ownership trade rests on, and it is NOT implied
        // by the ones above: `SPUUpdater(` lives inside
        // `SparkleUpdater.init`, so its source count stays 1
        // however many `SparkleUpdater()` a future Settings
        // section builds. Without this, the duplication
        // direction — two Sparkles scheduled against one app —
        // is guarded by nothing, which is what the first cut of
        // this suite claimed to prevent and did not.
        let conformers = try Self.sites(
            of: "SparkleUpdater(",
            under: Self.productionTrees
        )
        #expect(
            conformers.count == 1,
            .init(
                rawValue: "one SparkleUpdater() expected, got "
                    + "\(conformers.count)"
            )
        )
        #expect(
            conformers.allSatisfy {
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

    /// The install-and-restart prompt comes forward (#1011).
    ///
    /// A source scan because neither half of it reaches a unit
    /// test: the override puts a real window on screen out of
    /// `Sparkle.framework`, and `NSApp.activate` is the machine.
    /// What can be held is that the override still exists and
    /// still brings the app forward before handing the prompt
    /// back to Sparkle — drop either line and the prompt goes
    /// back to arriving behind every window the user has open,
    /// with `requestUserAttention` bouncing a Dock tile a
    /// menu-bar app does not have. Nothing else in this tree
    /// would red.
    @Test("the install prompt activates before Sparkle shows it")
    func installPromptComesForward() throws {
        let file = Self.root
            .appendingPathComponent("Sources/KiwiDesk/Updates")
            .appendingPathComponent(Self.updaterAllowed)
        let text = try SourceScan.strippedSource(at: file)
        let declaration =
            "override func showReadyToInstallAndRelaunch"
        guard let declared = text.range(of: declaration) else {
            Issue.record(
                .init(
                    rawValue: "no \(declaration) override in "
                        + Self.updaterAllowed
                )
            )
            return
        }
        let characters = Array(text)
        let offset = text.distance(
            from: text.startIndex,
            to: declared.lowerBound
        )
        guard
            var cursor = characters[offset...]
                .firstIndex(of: "{")
        else {
            Issue.record("the override has no body")
            return
        }
        guard
            let body = SourceScan.balanced(
                characters,
                from: &cursor,
                open: "{",
                close: "}"
            )
        else {
            Issue.record("the override body is unbalanced")
            return
        }
        #expect(
            body.contains(
                "NSApp.activate(ignoringOtherApps: true)"
            ),
            .init(
                rawValue: "the ready-to-install override must "
                    + "bring the app forward. Body: \(body)"
            )
        )
        #expect(
            body.contains("super.showReadyToInstallAndRelaunch("),
            "the override must still let Sparkle show the prompt"
        )
    }
}
