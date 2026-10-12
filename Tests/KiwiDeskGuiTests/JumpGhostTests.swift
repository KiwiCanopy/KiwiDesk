import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The field's stand-in for the typing (owner, 2026-10-12): the
/// selected row's name with the typed letters at full ink and the
/// rest grey, then what ↩ does; nothing without a selection.
@Suite("Jump to window field name")
@MainActor
struct JumpGhostTests {
    private func match(
        _ app: String,
        _ title: String = "",
        query: String
    ) throws -> JumpSearch.Match {
        let entry = JumpListTests.row(1, app, title)
        return try #require(
            JumpSearch.matches([entry], query: query).first
        )
    }

    private func inked(_ field: JumpGhost.Field) -> String {
        field.name.runs
            .filter { $0.foregroundColor == Color.primary }
            .map { String(field.name[$0.range].characters) }
            .joined()
    }

    @Test("the typed letters are inked inside the selected name")
    func typedLettersInked() throws {
        LocalizationManager.shared.select("en")
        let field = try #require(
            JumpGhost.field(
                selected: try match("Antigravity IDE", query: "ti"),
                moveHere: false
            )
        )
        #expect(String(field.name.characters) == "Antigravity IDE")
        #expect(inked(field) == "ti")
        // Ink alone marks them: the field keeps one weight.
        #expect(
            field.name.runs.allSatisfy {
                $0.inlinePresentationIntent == nil
            }
        )
        #expect(field.frame == "%1$@ — Jump")
    }

    @Test("nothing typed draws the whole name grey")
    func emptyQueryAllGrey() throws {
        LocalizationManager.shared.select("en")
        let field = try #require(
            JumpGhost.field(
                selected: try match("Mail", "Inbox", query: ""),
                moveHere: true
            )
        )
        #expect(inked(field).isEmpty)
        #expect(field.frame == "%1$@ — Move here")
    }

    @Test("no selection draws nothing over the typing")
    func noSelection() {
        #expect(JumpGhost.field(selected: nil, moveHere: false) == nil)
    }
}
