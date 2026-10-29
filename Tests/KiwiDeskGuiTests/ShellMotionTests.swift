import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The shell's transitions (#2737 ruling 13): each change records
/// its cause beside itself, and the shell plays that cause's motion.
/// Main-actor spend: one model and a scan of four files.
@MainActor
@Suite("Shell motion")
struct ShellMotionTests {
    @Test("the switch records a converge")
    func switchConverges() {
        let defaults = makeScratchDefaults().defaults
        SettingsRootPreference.write(.simple, to: defaults)
        let model = makeTestModel(defaults: defaults)
        #expect(model.nav.shellMotion == .none)
        model.pickRoot(.advanced)
        #expect(model.nav.shellMotion == .converge)
        model.nav.shellMotion = .none
        model.pickRoot(.simple)
        #expect(model.nav.shellMotion == .converge)
    }

    private func source(_ path: String) throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings/" + path)
        return try SourceScan.strippedSource(at: file)
            .filter { !$0.isWhitespace }
    }

    /// A cause set after its change would play the last change's
    /// motion, so each is recorded first.
    @Test("each door records its cause before its change")
    func causesComeFirst() throws {
        let doors = [
            "HomeScreen.swift":
                "model.nav.shellMotion=.expand(destination)"
                + "model.nav.homeReturnFocus=destination"
                + "model.destination=destination",
            "SettingsView+Reveal.swift":
                "model.nav.shellMotion=.zoomThrough"
                + "model.destination=resolved.destination",
            "SettingsModel+Root.swift":
                "nav.shellMotion=.convergesettingsRoot=root",
        ]
        for (file, needle) in doors {
            #expect(try source(file).contains(needle), "\(file)")
        }
    }

    /// The branches carry the cause's transition, and the one
    /// spring they ride is gated in its argument.
    @Test("the shell mounts each branch's transition, gated")
    func shellMountsTheMotion() throws {
        let shell = try source("SettingsView.swift")
        for needle in [
            "simplePane(width).transition(simpleTransition)",
            "HomeScreen(model:model).transition(homeTransition)",
            "detailPane(width).transition(pageTransition)",
            ".animation(reduceMotion?nil:ShellMotion.spring,"
                + "value:ShellMotion.Key(",
            ".environment(\\.shellSpace,reduceMotion?nil:shellSpace)",
        ] {
            #expect(shell.contains(needle), "\(needle)")
        }
        let home = try source("HomeScreen.swift")
        #expect(home.contains(".modifier(HomeConverge(arrived:arrived,"))
        #expect(home.contains("shellMotion!=.converge"))
    }

    /// A page's box joins its card's only while that card opened it,
    /// so a landing never morphs from a card it did not come from.
    @Test("only the opening card's page shares its box")
    func boxMatchesItsCard() throws {
        let detail = try source("SettingsView+Detail.swift")
        #expect(
            detail.contains(
                "model.nav.shellMotion==.expand(destination)"
            )
        )
        #expect(detail.contains(".background(pageBox)"))
        let card = try source("HomeCard.swift")
        #expect(card.contains("ShellMotion.boxID(destination)"))
        #expect(card.contains("ShellMotion.titleID(destination)"))
    }
}
