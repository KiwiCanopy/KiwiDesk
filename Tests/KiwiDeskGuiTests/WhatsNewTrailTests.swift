import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// "Show me" and the way back (#2038 ruling ▸ handoff): What's new
/// hides without finishing, Settings carries a banner whose Next
/// walks the linked rows, and ×, Back and the Settings close each
/// end it.
@MainActor
@Suite("What's new trail (#2038)", .serialized)
struct WhatsNewTrailTests {
    private static func entry(
        _ title: String,
        setting: String?
    ) -> UpdateNotesDigest.SpotlightEntry {
        .init(
            row: .init(title: title, line: "L.", setting: setting),
            version: "2.2.0"
        )
    }

    private static let rows = [
        entry("A", setting: "a"),
        entry("Unlinked", setting: nil),
        entry("Gone", setting: "renamed"),
        entry("B", setting: "b"),
    ]

    /// A landing that knows `a` and `b` alone.
    private static func landing(_ id: String?) -> SettingsAnchor? {
        guard let id, ["a", "b"].contains(id) else { return nil }
        return SettingsAnchor(destination: .shortcuts, anchor: id)
    }

    private final class Log {
        var back = 0
        var dismissed = 0
    }

    private static func trail(
        from picked: Int = 0,
        log: Log = Log()
    ) -> WhatsNewTrail? {
        WhatsNewTrail(
            spotlight: rows,
            picked: rows[picked],
            landing: landing,
            back: { log.back += 1 },
            dismiss: { log.dismissed += 1 }
        )
    }

    // MARK: - Next

    @Test("Next skips unlinked rows and is absent on the last")
    func nextSkipsUnlinked() throws {
        let first = try #require(Self.trail())
        #expect(first.stops.map(\.title) == ["A", "B"])
        #expect(first.next?.title == "B")
        let last = try #require(first.advanced())
        #expect(last.current.title == "B")
        #expect(last.next == nil)
        #expect(last.advanced() == nil)
    }

    @Test("a row this build cannot land on starts no trail")
    func unlinkedRowStartsNone() {
        #expect(Self.trail(from: 1) == nil)
        #expect(Self.trail(from: 2) == nil)
    }

    // MARK: - The banner's three ends

    private func model(with trail: WhatsNewTrail) -> SettingsModel {
        let model = makeTestModel()
        model.follow(trail)
        return model
    }

    @Test("following lands on the row as a search pick would")
    func followLands() throws {
        let model = model(with: try #require(Self.trail()))
        #expect(model.nav.pendingReveal?.anchor == "a")
        #expect(model.nav.pendingModeNotice == .shortcuts)
        model.followNext()
        #expect(model.whatsNewTrail?.current.title == "B")
        #expect(model.nav.pendingReveal?.anchor == "b")
    }

    @Test("× clears the banner and finishes What's new")
    func dismissEnds() throws {
        let log = Log()
        let model = model(with: try #require(Self.trail(log: log)))
        model.dismissWhatsNew()
        #expect(model.whatsNewTrail == nil)
        #expect(log.dismissed == 1)
        #expect(log.back == 0)
    }

    @Test("Back clears the banner and re-presents What's new")
    func backEnds() throws {
        let log = Log()
        let model = model(with: try #require(Self.trail(log: log)))
        model.returnToWhatsNew()
        #expect(model.whatsNewTrail == nil)
        #expect(log.back == 1)
        #expect(log.dismissed == 0)
    }

    @Test("closing Settings clears the banner and re-presents it")
    func settingsCloseEnds() throws {
        let log = Log()
        let model = model(with: try #require(Self.trail(log: log)))
        model.settingsClosed()
        #expect(model.whatsNewTrail == nil)
        #expect(log.back == 1)
        // Once: a second close has no trail to answer.
        model.settingsClosed()
        #expect(log.back == 1)
    }

    // MARK: - The window

    /// A real census id this build lands on.
    private static func linkedID() throws -> String {
        try #require(
            SettingsSearchIndex.rows().compactMap(\.key?.id).first
        )
    }

    private static func offer(setting: String) throws -> UpdateOffer {
        let notes = """
            {"format":1,"summary":"Intro.","sections":\
            [{"type":"new","title":"New","items":["N"]}],\
            "spotlight":[{"title":"Row","line":"L.",\
            "setting":"\(setting)"}]}
            """
        return try #require(
            UpdateOffer.whatsNew(
                items: [
                    .init(
                        version: "2.2.0",
                        shown: "2.2.0",
                        released: nil,
                        notes: notes
                    )
                ],
                since: "2.1.0",
                current: "2.2.0"
            )
        )
    }

    @Test("Show me hides What's new without finishing it; Back returns")
    func showMeHidesAndBackReturns() throws {
        let offer = try Self.offer(setting: try Self.linkedID())
        var done = 0
        var handed: [WhatsNewTrail] = []
        let controller = WhatsNewWindowController(
            offer: offer,
            narration: nil,
            next: nil,
            showsInSettings: { handed.append($0) }
        ) { done += 1 }
        var reshown: [NSWindow] = []
        controller.reshows = { reshown.append($0) }
        let window = controller.makeWindow()
        let row = try #require(offer.digest?.spotlight.first)

        controller.showMe(row)
        #expect(done == 0)
        #expect(!controller.isShown)
        let trail = try #require(handed.first)
        #expect(trail.current.title == "Row")

        trail.back()
        #expect(reshown.count == 1)
        #expect(reshown.first === window)
        #expect(done == 0)

        trail.dismiss()
        #expect(done == 1)
    }

    /// The census reading `changelog-sync` checks rows against,
    /// held to the census itself — the script reads Swift source
    /// so a draft needs no build.
    @Test("the script's census ids are SettingKey's")
    func censusDumpMatches() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let run = try GuiScriptFixture.python([
            root.appendingPathComponent("scripts/changelog-sync").path,
            "--census-ids",
        ])
        #expect(run.status == 0, "\(run.stderr)")
        let dumped = Set(run.stdout.split(separator: "\n").map(String.init))
        #expect(dumped == Set(SettingKey.allCases.map(\.id)))
    }
}

/// The Settings close re-shows a hidden What's new (#2038 ruling
/// ▸ handoff 6): the model's answer is pinned above; what a test
/// cannot see is the window's close reaching it.
@Suite("What's new trail wiring (#2038)")
struct WhatsNewTrailWiringTests {
    private static let gui = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk")

    private static func body(
        of declaration: String,
        in file: String
    ) throws -> String {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: gui.appendingPathComponent(file),
                encoding: .utf8
            )
        )
        return try #require(
            SourceScan.declarationBody(after: declaration, in: source)
        )
    }

    @Test("the Settings window's close ends the trail")
    func settingsCloseReachesTheModel() throws {
        let body = try Self.body(
            of: "func windowWillClose(",
            in: "Settings/SettingsWindowController.swift"
        )
        #expect(body.contains("model.settingsClosed()"))
    }

    @Test("the app hands What's new's trail to Settings")
    func appWiresTheHandoff() throws {
        let body = try Self.body(
            of: "func offerWhatsNew(",
            in: "AppDelegate+WhatsNew.swift"
        )
        #expect(body.contains("whatsNew.showsInSettings = {"))
        #expect(body.contains("dashboard.follow(trail)"))
    }
}
