import Foundation
import Testing

/// A gallery link's look is worn before Settings fronts (#2863):
/// the window draws its first frame inside the front, so a look
/// worn after it shows the plates in the previous look's verdict
/// for a frame. Reads the source; no main actor.
@Suite("Look link wears before the window fronts")
struct LookLinkFrontOrderTests {
    /// `name`'s brace-balanced body in `Sources/KiwiDesk/<file>`,
    /// whitespace dropped.
    private func body(_ name: String, in file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
            .appendingPathComponent(file)
        let text = Array(try SourceScan.strippedSource(at: url))
        let marker = Array("func \(name)")
        let start = try #require(
            text.indices.first { i in
                text[i...].starts(with: marker)
            }
        )
        // The body's brace, past a default closure's `= {}`.
        var cursor = try #require(
            text[start...].indices.first { i in
                guard text[i] == "{" else { return false }
                let before = text[..<i].last { !$0.isWhitespace }
                return before != "="
            }
        )
        let found = try #require(
            SourceScan.balanced(text, from: &cursor, open: "{", close: "}")
        )
        return found.filter { !$0.isWhitespace }
    }

    @Test("the link wears its look inside show's closure")
    func linkWearsBeforeFront() throws {
        let link = try body(
            "addLinkedLook",
            in: "AppDelegate+LookLink.swift"
        )
        #expect(
            link.contains(
                "dashboard.show{self.dashboard.model.wearLinkedLook(look)}"
            )
        )
        #expect(!link.contains("dashboard.show()"))
    }

    @Test("show edits the draft after the reload and before the front")
    func showOrdersTheEdit() throws {
        let show = try body(
            "show(beforeFront",
            in: "Settings/SettingsWindowController.swift"
        )
        let reload = try #require(show.range(of: "model.prepareToShow("))
        let edit = try #require(show.range(of: "beforeFront()"))
        let front = try #require(show.range(of: "NSApp.forceFront("))
        #expect(reload.upperBound <= edit.lowerBound)
        #expect(edit.upperBound <= front.lowerBound)
    }
}
