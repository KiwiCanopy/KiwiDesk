import Foundation
import Testing

@testable import KiwiDesk

/// An App Rules add reveals and focuses the row it made (#3450 ▸
/// Ruling): the live sort moves a picked app from the picker at the
/// list's foot to its alphabetical slot, so the add scrolls to that
/// row and hands it focus through the returning-row destination a
/// deletion uses (`KeyboardActionParityTests`), then lights it with
/// search's landing flash (#3490). Each needle names a use site,
/// comments stripped and whitespace squashed so a reflow owes
/// nothing. Off the main actor: five file reads and one walk of
/// `Sources/KiwiDesk`.
@Suite("App Rules ▸ an add reveals its row (#3450)")
struct AppRuleAddRevealTests {
    private var sections: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings/Sections")
    }

    private func source(_ file: String) throws -> String {
        let text = try String(
            contentsOf: sections.appendingPathComponent(file),
            encoding: .utf8
        )
        return squashed(SourceScan.stripComments(text))
    }

    private func squashed(_ source: String) -> String {
        source.split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("each add names its row's anchor and its focus")
    func addsRevealAndFocus() throws {
        let lists = try source("AppRulesSection+Lists.swift")
        let auto = try source("AppRulesSection+Automatic.swift")
        let needles: [(String, String)] = [
            // Each add names its row last, after the write, so
            // nothing after it can undo the reveal.
            (
                lists,
                "model.config.appRules[app]=space"
                    + "letkey=SpaceRuleRow(app:app,fragment:nil).key"
                    + "revealedRow=RowReveal(list:.space,key:key)}"
            ),
            (
                lists,
                "model.config.floatRules.append(app)"
                    + "revealedRow=RowReveal(list:.float,key:app)}"
            ),
            (
                auto,
                "model.config.tileRules.append(app)"
                    + "revealedRow=RowReveal(list:.tile,"
                    + "key:FloatGuess.normalizedRule(app))}"
            ),
            // The anchors the adds name, on the rows drawn.
            (
                lists,
                "returningRow:$returningSpaceRow)"
                    + ".rowAnchored(Self.anchor(.space,row.key))"
            ),
            (
                lists,
                "returningRow:$returningFloatRow)"
                    + ".rowAnchored(Self.anchor(.float,app))"
            ),
            (
                auto,
                "returningRow:$returningTileRow)"
                    + ".rowAnchored(Self.anchor(.tile,app))"
            ),
        ]
        for (file, needle) in needles {
            #expect(file.contains(needle), "lost `\(needle)`")
        }
    }

    @Test("the page scrolls, settles, scrolls again, then focuses")
    func pageScrollsThenFocuses() throws {
        let page = try source("AppRulesSection.swift")
        let task: String =
            ".task(id:revealedRow){guardletreveal=revealedRow"
            + "else{return}awaitself.reveal(reveal,proxy)}"
        let settles: String =
            "proxy.scrollTo(anchor,anchor:.center)"
            + "try?awaitTask.sleep("
        // Focus after the row is drawn, each list into its own
        // destination (#816).
        let focuses: String =
            "guard!Task.isCancelledelse{return}"
            + "proxy.scrollTo(anchor,anchor:.center)"
            + "switchrow.list{"
            + "case.space:returningSpaceRow=row.key"
            + "case.float:returningFloatRow=row.key"
            + "case.tile:returningTileRow=row.key}"
        // Then the row lights with search's own landing flash, and
        // a task a later add cancelled leaves `revealedRow` to that
        // add (#3490).
        let flashes: String =
            "awaitmodel.flashReveal(anchor,reduceMotion:reduceMotion)"
            + "guard!Task.isCancelledelse{return}revealedRow=nil}"
        for needle in [task, settles, focuses, flashes] {
            #expect(page.contains(needle), "lost `\(needle)`")
        }
        // Search's landing takes the same helper: one flash.
        let detail = squashed(
            SourceScan.stripComments(
                try String(
                    contentsOf: sections.deletingLastPathComponent()
                        .appendingPathComponent("SettingsView+Detail.swift"),
                    encoding: .utf8
                )
            )
        )
        #expect(
            detail.contains(
                "awaitmodel.flashReveal(anchor,reduceMotion:reduceMotion)"
            )
        )
        // One flash: nothing outside its home starts or ends one.
        var callers: [String] = []
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        for file in try SourceScan.swiftSources(under: root) {
            let text = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            if text.contains(".startFlash(") || text.contains(".endFlash(") {
                callers.append(file.lastPathComponent)
            }
        }
        #expect(callers == ["SettingsReveal.swift"])
    }

    @Test("Add Rule… reveals the titled rule it made (#3490)")
    func titledAddReveals() throws {
        let scope = try source("AppRuleSpaceRow+Scope.swift")
        let lists = try source("AppRulesSection+Lists.swift")
        let needles: [(String, String)] = [
            (
                scope,
                "config:&model.config)else{return}onAdd(made.key)}}"
            ),
            (
                lists,
                "onAdd:{revealedRow=RowReveal(list:.space,key:$0)},"
                    + "returningRow:$returningSpaceRow)"
            ),
        ]
        for (file, needle) in needles {
            #expect(file.contains(needle), "lost `\(needle)`")
        }
    }

    @Test("the lists' anchors never collide")
    @MainActor
    func anchorsAreApart() {
        let anchors = [.space, .float, .tile].map {
            AppRulesSection.anchor($0, "com.a")
        }
        #expect(Set(anchors).count == 3)
    }
}
