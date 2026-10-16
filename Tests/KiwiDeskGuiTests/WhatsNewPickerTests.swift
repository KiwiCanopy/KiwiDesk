import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// What's new's release menu in its window (#2308): a "Show me"
/// hands off the rows of the release on screen, Back and a
/// Settings close return to Home's window, the window is as tall
/// as the tallest release, and the view wiring that carries a
/// pick holds.
@MainActor
@Suite("What's new release menu window (#2308)", .serialized)
struct WhatsNewPickerTests {
    private final class Log {
        var fronted: [NSWindow] = []
        var hidden: [NSWindow] = []
        var trails: [WhatsNewTrail] = []
    }

    /// A census id this build lands on.
    private static func linkedID() throws -> String {
        try #require(
            SettingsSearchIndex.rows().compactMap(\.key?.id).first
        )
    }

    private static func notes(_ title: String, _ id: String) -> String {
        """
        {"format":1,"summary":"Intro.","sections":\
        [{"type":"new","title":"New","items":["N"]}],\
        "spotlight":[{"title":"\(title)","line":"L.",\
        "setting":"\(id)"}]}
        """
    }

    private static func browsing() async throws -> (
        WhatsNewCoordinator, WhatsNewWindowController, Log
    ) {
        let id = try linkedID()
        let feed: [WhatsNewFeed.Item] = [
            .init(
                version: "9999.2.0",
                shown: "9999.2.0",
                released: nil,
                notes: notes("Newer", id)
            ),
            .init(
                version: "9999.1.0",
                shown: "9999.1.0",
                released: nil,
                notes: notes("Older", id)
            ),
        ]
        let (coordinator, _, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.2.0",
            feed: feed
        )
        let log = Log()
        var shown: WhatsNewWindowController?
        coordinator.presents = { controller in
            shown = controller
            controller.fronts = { log.fronted.append($0) }
            controller.hides = { log.hidden.append($0) }
            controller.present()
        }
        coordinator.showsInSettings = { log.trails.append($0) }
        coordinator.browse()
        await coordinator.browseFetch?.value
        return (coordinator, try #require(shown), log)
    }

    @Test("Show me hands off the picked release's rows; Back returns")
    func showMeAfterAPick() async throws {
        let (coordinator, controller, log) = try await Self.browsing()
        let menu = try #require(controller.menu)
        let older = try #require(
            menu.releases.offer(for: .release("9999.1.0"))
        )
        controller.didShow(older)
        let row = try #require(older.digest?.spotlight.first)
        coordinator.showMe(row)
        let trail = try #require(log.trails.first)
        #expect(trail.current.title == "Older")
        #expect(controller.hidden)
        trail.back()
        #expect(!controller.hidden)
        #expect(log.fronted.count == 2)
    }

    @Test("A Settings close brings Home's window back")
    func settingsCloseReturns() async throws {
        let (coordinator, controller, log) = try await Self.browsing()
        let row = try #require(controller.shown.digest?.spotlight.first)
        coordinator.showMe(row)
        try #require(log.trails.first).settingsClosed()
        #expect(!controller.hidden)
        #expect(log.fronted.count == 2)
    }

    @Test("The window is as tall as the tallest release")
    func tallestReleaseSizesTheWindow() throws {
        let long = (1...40).map { "\"Entry \($0)\"" }.joined(separator: ",")
        let longNotes = """
            {"format":1,"summary":"S.","sections":\
            [{"type":"new","title":"New","items":[\(long)]}]}
            """
        let releases = try #require(
            WhatsNewReleases(
                items: [
                    .init(
                        version: "9999.2.0",
                        shown: "9999.2.0",
                        released: nil,
                        notes: WhatsNewFixture.notes("short")
                    ),
                    .init(
                        version: "9999.1.0",
                        shown: "9999.1.0",
                        released: nil,
                        notes: longNotes
                    ),
                ],
                current: "9999.2.0"
            )
        )
        let menu = try #require(WhatsNewMenu(releases, owed: false))
        func height(_ menu: WhatsNewMenu?, _ offer: UpdateOffer) -> CGFloat {
            WhatsNewWindowController(
                offer: offer,
                narration: nil,
                next: nil,
                menu: menu,
                showMe: { _ in },
                done: {}
            ).makeWindow().frame.height
        }
        // The opening release alone is short; the menu's older,
        // longer release decides the height.
        #expect(height(menu, menu.offer) > height(nil, menu.offer))
    }

    private static func source(_ file: String) throws -> String {
        try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk/Updates/\(file)")
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    /// The pick reaches `shown` — a "Show me" otherwise hands off
    /// the opening release's rows and finds nothing — the notes
    /// reopen per release, and every notes window links the site.
    @Test("A pick is carried to the window, the notes and the links")
    func pickWiring() throws {
        #expect(
            try Self.source("WhatsNewReleasePicker.swift")
                .contains(".onChange(of:selection){onShow(offer)}")
        )
        #expect(
            try Self.source("WhatsNewWindowController.swift")
                .contains("{[weakself]inself?.didShow($0)}")
        )
        let view = try Self.source("UpdateWindowView.swift")
        #expect(view.contains(".id(picking?.selection.wrappedValue)"))
        // The changelog link rides the installed notes' flag, so the
        // offer, whose flag is false, never draws it.
        #expect(
            try Self.source("UpdateNotesScroll.swift").contains(
                "ifwhatsNew{UpdateNotesLink("
            )
        )
    }
}
