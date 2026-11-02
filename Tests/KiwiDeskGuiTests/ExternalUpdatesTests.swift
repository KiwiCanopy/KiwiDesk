import Foundation
import Testing

@testable import KiwiDesk

/// A copy a package manager installs keeps Sparkle off and says
/// who updates it (#2909).
@MainActor
@Suite("Package-managed updates (#2909)")
struct ExternalUpdatesTests {
    private static let applications = "/Applications/KiwiDesk.app"
    private static let store =
        "/nix/store/abc123-kiwidesk-4.2.0/Applications/KiwiDesk.app"
    private static let copied =
        "/Users/me/Applications/Home Manager Apps/KiwiDesk.app"

    @Test("an ordinary install leaves updates to Sparkle")
    func ordinaryInstall() {
        #expect(
            ExternalUpdates.manager(
                declared: nil,
                bundlePath: Self.applications
            ) == nil
        )
    }

    /// Home Manager's copy sits outside the store, so only the key
    /// the module writes can name it.
    @Test("the declared manager names a copy outside the store")
    func declaredNamesTheCopy() {
        #expect(
            ExternalUpdates.manager(
                declared: "Home Manager",
                bundlePath: Self.copied
            ) == "Home Manager"
        )
    }

    @Test("a store-path bundle is Nix's without the key")
    func storePathIsNix() {
        #expect(
            ExternalUpdates.manager(declared: nil, bundlePath: Self.store)
                == "Nix"
        )
    }

    /// A blank value would draw "come from ." and still hide the
    /// updater the user needs.
    @Test("a blank declaration is no declaration")
    func blankIsIgnored() {
        #expect(
            ExternalUpdates.manager(
                declared: "  \n",
                bundlePath: Self.applications
            ) == nil
        )
    }

    @Test("a managed copy carries the manager into both readers")
    func managedUpdaterSaysWho() {
        let updater = NoUpdater(managedBy: "Home Manager")
        #expect(!updater.canCheckForUpdates)
        #expect(updater.updates.state == .managed(by: "Home Manager"))
        #expect(
            updater.autoInstall.unavailable
                == .managed(by: "Home Manager")
        )
    }

    @Test("an unbundled run keeps its own reasons")
    func unbundledIsUnchanged() {
        let updater = NoUpdater()
        #expect(updater.updates.state == .unavailable)
        #expect(updater.autoInstall.unavailable == .noChannel)
    }

    @Test("the automatic-install reason is the footer's sentence")
    func gateReadsTheFooterSentence() {
        #expect(
            GeneralGateHelp.sentence(
                for: .automaticInstall(.managed(by: "Nix"))
            ) == UpdateStateRow.managedSentence("Nix")
        )
    }
}
