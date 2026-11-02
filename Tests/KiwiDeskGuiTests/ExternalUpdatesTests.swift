import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

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

    private static let folder =
        "/Users/me/Applications/Home Manager Apps"

    @Test("an ordinary install leaves updates to Sparkle")
    func ordinaryInstall() {
        #expect(
            ExternalUpdates.manager(
                declared: nil,
                folder: nil,
                bundlePath: Self.applications
            ) == nil
        )
    }

    /// Home Manager's copy sits outside the store, so only the
    /// keys the module writes can name it.
    @Test("the declared manager names a copy in its folder")
    func declaredNamesTheCopy() {
        #expect(
            ExternalUpdates.manager(
                declared: "Home Manager",
                folder: Self.folder,
                bundlePath: Self.copied
            ) == "Home Manager"
        )
    }

    /// The keys outlive the module: a user who left Nix for the
    /// cask must get Sparkle back, not a channel that never runs.
    @Test("a stale declaration leaves another copy to Sparkle")
    func staleKeyIgnored() {
        #expect(
            ExternalUpdates.manager(
                declared: "Home Manager",
                folder: Self.folder,
                bundlePath: Self.applications
            ) == nil
        )
    }

    /// A folder that merely shares a prefix is another folder.
    @Test("a sibling folder with the same prefix is not inside")
    func siblingFolderIsOutside() {
        #expect(
            ExternalUpdates.manager(
                declared: "Home Manager",
                folder: Self.folder,
                bundlePath: Self.folder + " Old/KiwiDesk.app"
            ) == nil
        )
    }

    /// Only `.standardized` folds a `.` segment; a bare `.path`
    /// already drops a trailing slash.
    @Test("a folder spelled with a dot segment still holds the copy")
    func folderIsStandardized() {
        #expect(
            ExternalUpdates.manager(
                declared: "Home Manager",
                folder: "/Users/me/Applications/./Home Manager Apps",
                bundlePath: Self.copied
            ) == "Home Manager"
        )
    }

    @Test("a declaration without its folder names nothing")
    func nameNeedsItsFolder() {
        #expect(
            ExternalUpdates.manager(
                declared: "Home Manager",
                folder: nil,
                bundlePath: Self.copied
            ) == nil
        )
    }

    @Test("a store-path bundle is Nix's without the keys")
    func storePathIsNix() {
        #expect(
            ExternalUpdates.manager(
                declared: nil,
                folder: nil,
                bundlePath: Self.store
            ) == "Nix"
        )
    }

    /// A blank value would draw "come from ." and still hide the
    /// updater the user needs.
    @Test("a blank declaration is no declaration")
    func blankIsIgnored() {
        #expect(
            ExternalUpdates.manager(
                declared: "  \n",
                folder: Self.folder,
                bundlePath: Self.copied
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

    /// The two key spellings are a contract with the Home Manager
    /// module in KiwiCanopy/nix, which writes them; a rename here
    /// moves that module in step.
    @Test("the running copy reads the keys the module writes")
    func currentReadsTheModulesKeys() {
        let (defaults, name) = makeScratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("Home Manager", forKey: "KiwiDeskUpdatesManagedBy")
        defaults.set(
            Self.folder,
            forKey: "KiwiDeskUpdatesManagedFolder"
        )
        #expect(
            ExternalUpdates.current(
                defaults: defaults,
                bundlePath: Self.copied
            ) == "Home Manager"
        )
        // A Bool would read as "1" through `string(forKey:)`.
        defaults.set(true, forKey: "KiwiDeskUpdatesManagedBy")
        #expect(
            ExternalUpdates.current(
                defaults: defaults,
                bundlePath: Self.copied
            ) == nil
        )
    }

    @Test("the automatic-install reason is the footer's sentence")
    func gateReadsTheFooterSentence() {
        LocalizationManager.shared.select("en")
        let sentence = GeneralGateHelp.sentence(
            for: .automaticInstall(.managed(by: "Home Manager"))
        )
        #expect(sentence == UpdateStateRow.managedSentence("Home Manager"))
        #expect(sentence.contains("Home Manager"))
    }
}
