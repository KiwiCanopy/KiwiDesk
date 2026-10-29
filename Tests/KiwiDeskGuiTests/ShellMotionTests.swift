import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The shell's transitions (#2737 ruling 13): every change of the
/// shown root or destination records its cause where the change
/// happens, so the shell plays that cause's motion. Main-actor
/// spend: models and a scan of the Settings tree.
@MainActor
@Suite("Shell motion")
struct ShellMotionTests {
    private func model(_ root: SettingsRoot = .simple) -> SettingsModel {
        let defaults = makeScratchDefaults().defaults
        SettingsRootPreference.write(root, to: defaults)
        return makeTestModel(defaults: defaults)
    }

    @Test("the switch converges, and owes Home one converge")
    func switchConverges() {
        let model = model()
        #expect(model.nav.shellMotion == .none)
        model.pickRoot(.advanced)
        #expect(model.nav.shellMotion == .converge)
        #expect(model.nav.convergePending)
        model.nav.convergePending = false
        model.pickRoot(.simple)
        #expect(model.nav.shellMotion == .converge)
        // The bare header link is a switch too.
        model.openAdvanced()
        #expect(model.nav.shellMotion == .converge)
    }

    /// Inside Advanced a page swaps at once: no door records a
    /// motion, so the shell's spring, keyed on the root, stays still.
    @Test("a card's page and a landing record no motion")
    func pagesSwapAtOnce() {
        let model = model(.advanced)
        // Home paid the opening converge.
        model.nav.convergePending = false
        let opened = model.nav.shellMotion
        model.openFromCard(.bars)
        #expect(model.nav.shellMotion == opened)
        #expect(model.nav.homeReturnFocus == .bars)
        model.destination = .looks
        model.destination = nil
        #expect(model.nav.shellMotion == opened)
        #expect(!model.nav.convergePending)
        // A link from Simple lands on its page, not a converge.
        let simple = self.model()
        simple.destination = .looks
        #expect(simple.showsSimple == false)
        #expect(simple.nav.shellMotion == .none)
        #expect(!simple.nav.convergePending)
    }

    /// The cause has one owner, so a new door cannot leave the last
    /// change's motion standing.
    @Test("only the root writes the cause")
    func causeHasOneOwner() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: root)
        #expect(!files.isEmpty)
        let allowed: [String: Int] = [
            "SettingsModel+ShellMotion.swift": 1,
            "SettingsNavigation.swift": 1,
        ]
        var found: [String: Int] = [:]
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
                .filter { !$0.isWhitespace }
            // An assignment, never a comparison.
            let count =
                text.occurrences(of: "shellMotion=")
                - text.occurrences(of: "shellMotion==")
            if count > 0 { found[file.lastPathComponent] = count }
        }
        #expect(found == allowed, "\(found)")
    }

    private func source(_ path: String) throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings/" + path)
        return try SourceScan.strippedSource(at: file)
            .filter { !$0.isWhitespace }
    }

    /// The branches carry their transitions, and the one spring
    /// they ride is gated in its argument and keyed on the root.
    @Test("the shell mounts each branch's transition, gated")
    func shellMountsTheMotion() throws {
        let shell = try source("SettingsView.swift")
        for needle in [
            "simplePane(width).transition(simpleTransition)",
            "HomeScreen(model:model).transition(homeTransition)",
            "detailPane(width).transition(pageTransition)",
            ".animation(reduceMotion?nil:ShellMotion.spring,"
                + "value:shellBranch)",
            // Home to a page is not a branch change, so it swaps
            // unanimated.
            "model.showsSimple?.simple:.advanced",
        ] {
            #expect(shell.contains(needle), "\(needle)")
        }
        let home = try source("HomeScreen.swift")
        #expect(home.contains(".modifier(HomeConverge(arrived:arrived,"))
        #expect(
            home.contains("State(initialValue:!model.nav.convergePending)")
        )
        #expect(home.contains("model.openFromCard(destination)"))
        // The cards land once, and Home clears the debt it paid.
        #expect(
            home.contains(
                ".onAppear{arrived=truemodel.nav.convergePending=false}"
            )
        )
    }
}
