import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The shell's transitions (#2737 ruling 13): only the root switch
/// moves, and only a switch landing on Home owes the cards' converge.
/// Main-actor spend: models and a scan of the Settings tree.
@MainActor
@Suite("Shell motion")
struct ShellMotionTests {
    private func model(_ root: SettingsRoot = .simple) -> SettingsModel {
        let defaults = makeScratchDefaults().defaults
        SettingsRootPreference.write(root, to: defaults)
        return makeTestModel(defaults: defaults)
    }

    @Test("the switch owes the root it lands on one converge")
    func switchConverges() {
        let model = model()
        #expect(!model.nav.convergePending)
        model.pickRoot(.advanced)
        #expect(model.nav.convergePending)
        model.nav.convergePending = false
        // Simple's sections fly in too (#2777), and pay it on arrival.
        model.pickRoot(.simple)
        #expect(model.nav.convergePending)
        model.nav.convergePending = false
        // The bare header link is a switch too.
        model.openAdvanced()
        #expect(model.nav.convergePending)
    }

    /// Inside Advanced a page swaps at once, so no page write owes
    /// a converge.
    @Test("a card's page and a landing owe no converge")
    func pagesSwapAtOnce() {
        let model = model()
        model.pickRoot(.advanced)
        // What Home's onAppear does once the cards have landed.
        model.nav.convergePending = false
        model.openFromCard(.bars)
        #expect(model.nav.homeReturnFocus == .bars)
        model.destination = nil
        model.destination = .looks
        model.destination = nil
        #expect(!model.nav.convergePending)
        // A link from Simple lands on its page, not a converge.
        let simple = self.model()
        simple.destination = .looks
        #expect(simple.showsSimple == false)
        #expect(!simple.nav.convergePending)
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
            "SimpleScreen(model:model).transition(simpleTransition)",
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
        // Simple's sections take Home's flight and pay its debt
        // (#2777).
        let simple = try source("SimpleScreen.swift")
        #expect(simple.contains(".modifier(converge(0,geo.size))"))
        #expect(
            simple.contains("State(initialValue:!model.nav.convergePending)")
        )
        #expect(
            simple.contains(
                ".onAppear{arrived=truemodel.nav.convergePending=false}"
            )
        )
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
