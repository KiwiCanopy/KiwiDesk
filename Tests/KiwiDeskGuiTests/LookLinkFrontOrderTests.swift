import Foundation
import Testing

/// A gallery link's look is worn before Settings fronts (#2863):
/// the window draws its first frame inside the front, so a look
/// worn after it shows the plates in the previous look's verdict
/// for a frame. Reads the source; no main actor.
@Suite("Look link wears before the window fronts")
struct LookLinkFrontOrderTests {
    @Test("the link wears its look inside show's closure")
    func linkWearsBeforeFront() throws {
        func body(_ name: String) throws -> String {
            try SourceScan.functionBody(
                of: name,
                in: "AppDelegate+LookLink.swift",
                under: "",
                root: "Sources/KiwiDesk"
            ).filter { !$0.isWhitespace }
        }
        let wear = try body("wear")
        #expect(
            wear.contains(
                "dashboard.show{self.dashboard.model.wearLinkedLook(look)}"
            )
        )
        // A held look and a downloaded one both wear through it
        // (#2943).
        let link = try body("addLinkedLook")
        #expect(link.contains("wear(held)"))
        #expect(link.contains("wear(look)"))
        #expect(!link.contains("dashboard.show"))
    }

    @Test("show edits the draft after the reload and before the front")
    func showOrdersTheEdit() throws {
        let show = try SourceScan.functionBody(
            of: "show",
            labeled: "beforeFront",
            in: "SettingsWindowController.swift",
            under: "Settings",
            root: "Sources/KiwiDesk"
        ).filter { !$0.isWhitespace }
        let reload = try #require(show.range(of: "model.prepareToShow("))
        let edit = try #require(show.range(of: "beforeFront()"))
        let own = try #require(show.range(of: "focusOwnWindow("))
        let front = try #require(show.range(of: "NSApp.forceFront("))
        #expect(reload.upperBound <= edit.lowerBound)
        #expect(edit.upperBound <= own.lowerBound)
        #expect(edit.upperBound <= front.lowerBound)
    }
}
