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

    @Test("a card's page expands, and Back folds into the card")
    func cardExpands() {
        let model = model(.advanced)
        model.openFromCard(.bars)
        #expect(model.nav.shellMotion == .expand(.bars))
        #expect(model.nav.pendingShellMotion == nil)
        model.destination = nil
        #expect(model.nav.shellMotion == .expand(.bars))
    }

    /// Only Home arriving owes the flight, and a landing breaks the
    /// line back to a card.
    @Test("a debt is owed only where it is paid")
    func debtsArePaidWhereOwed() {
        let model = model(.advanced)
        model.pickRoot(.simple)
        #expect(!model.nav.convergePending)
        model.openAdvanced(SettingsAnchor(destination: .looks))
        model.destination = .looks
        model.destination = nil
        #expect(!model.nav.convergePending)
        #expect(model.nav.shellMotion == .zoomThrough)
        // A card's page owes its late fade; a landing pays it off.
        model.openFromCard(.bars)
        #expect(model.nav.contentLagPending)
        model.destination = .looks
        #expect(!model.nav.contentLagPending)
        #expect(model.nav.homeReturnFocus == nil)
        model.destination = .bars
        model.destination = nil
        #expect(model.nav.shellMotion == .zoomThrough)
    }

    /// A landing — a search hit, a link, a page-to-page jump —
    /// has no card behind it, so it never morphs from one.
    @Test("a landing with no card zooms through")
    func landingZooms() {
        let model = model(.advanced)
        model.destination = .spaces
        #expect(model.nav.shellMotion == .zoomThrough)
        model.openFromCard(.bars)
        model.destination = .looks
        #expect(model.nav.shellMotion == .zoomThrough)
        // Back from a page no card opened.
        model.destination = nil
        #expect(model.nav.shellMotion == .zoomThrough)
        // A link from Simple lands on its page, not a converge.
        let simple = self.model()
        simple.destination = .looks
        #expect(simple.showsSimple == false)
        #expect(simple.nav.shellMotion == .zoomThrough)
    }

    /// The cause has one owner, so a new door cannot leave the last
    /// change's motion standing.
    @Test("only the root and destination write the cause")
    func causeHasOneOwner() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: root)
        #expect(!files.isEmpty)
        let allowed: [String: Int] = [
            "SettingsModel+ShellMotion.swift": 4,
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
    /// they ride is gated in its argument.
    @Test("the shell mounts each branch's transition, gated")
    func shellMountsTheMotion() throws {
        let shell = try source("SettingsView.swift")
        for needle in [
            "simplePane(width).transition(simpleTransition)",
            "HomeScreen(model:model).transition(homeTransition)",
            "detailPane(width).transition(pageTransition)",
            ".animation(reduceMotion?nil:ShellMotion.spring,"
                + "value:shellBranch)",
            ".environment(\\.shellSpace,reduceMotion?nil:shellSpace)",
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

    /// A page's box joins its card's only while that card opened it.
    @Test("only the opening card's page shares its box")
    func boxMatchesItsCard() throws {
        let detail = try source("SettingsView+Detail.swift")
        #expect(
            detail.contains(
                "ifletdestination=model.destination,"
                    + "model.nav.shellMotion==.expand(destination){"
            )
        )
        #expect(detail.contains(".background(pageBox)"))
        // The box stays opaque; only the content on it lags.
        #expect(
            detail.contains(
                "contentColumn.modifier(PageContentLag(lags:pageExpands))"
            )
        )
        let card = try source("HomeCard.swift")
        for id in ["boxID", "titleID"] {
            #expect(
                card.contains(
                    ".shellMatched(ShellMotion.\(id)(destination),"
                        + "in:shellSpace)"
                ),
                "\(id)"
            )
        }
    }
}
