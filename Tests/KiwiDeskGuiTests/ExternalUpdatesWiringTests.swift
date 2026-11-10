import Foundation
import Testing

@testable import KiwiDesk

/// What the app does with the package-manager answer (#2909): the
/// pure choice, and the two sites that act on it. The counted call
/// sites are `UpdaterSeamGuardTests`'.
@MainActor
@Suite("Package-managed updates are wired (#2909)")
struct ExternalUpdatesWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// The file with comments stripped and no whitespace, so a
    /// needle names the shape a format pass cannot move.
    private static func squeezed(_ path: String) throws -> String {
        let file = root.appendingPathComponent(path)
        return SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        ).filter { !$0.isWhitespace }
    }

    @Test("a managed copy never gets Sparkle")
    func managedBeatsSparkle() {
        #expect(
            AppUpdaterFactory.choice(bundled: true, manager: "Nix")
                == .managed(by: "Nix")
        )
    }

    @Test("an unowned bundled copy gets Sparkle")
    func unownedGetsSparkle() {
        #expect(
            AppUpdaterFactory.choice(bundled: true, manager: nil)
                == .sparkle
        )
    }

    /// An unbundled run says "update checks are off", not who
    /// installs updates it never had.
    @Test("an unbundled run stays inert whatever the keys say")
    func unbundledStaysInert() {
        #expect(
            AppUpdaterFactory.choice(bundled: false, manager: "Nix")
                == .inert
        )
    }

    /// Each arm RETURNS its updater, and Sparkle is built only in
    /// its own arm: a `SparkleUpdater()` hoisted above the switch
    /// starts Sparkle on a Nix copy with every count still at one.
    @Test("make() returns what the choice picks")
    func makeActsOnTheChoice() throws {
        let source = try Self.squeezed(
            "Sources/KiwiDesk/Updates/AppUpdater.swift"
        )
        for arm in [
            "switchchoice(bundled:bundled,manager:manager){",
            "case.inert:returnNoUpdater()",
            "case.managed(letmanager):returnManagedUpdater("
                + "manager:manager,host:main,record:WhatsNewRecord())",
            "case.sparkle:returnSparkleUpdater()",
            "ExternalUpdates.current(defaults:AppDefaults.store,"
                + "bundlePath:main.bundlePath)",
        ] {
            #expect(source.contains(arm), Comment(rawValue: arm))
        }
    }

    /// The footer's branch draws the managed sentence, not the
    /// unbundled one (`UpdateStateRow`).
    @Test("the footer draws the managed sentence")
    func footerDrawsTheManagedSentence() throws {
        let source = try Self.squeezed(
            "Sources/KiwiDesk/Settings/Home/UpdateStateRow.swift"
        )
        let branch =
            "case.managed(letmanager):"
            + "sentence(Self.managedSentence(manager)"
        #expect(source.contains(branch))
    }
}
