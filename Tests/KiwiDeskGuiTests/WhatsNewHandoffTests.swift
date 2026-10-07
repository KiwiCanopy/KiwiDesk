import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The window's half of "Show me" (#2038 ruling ▸ handoff), on
/// the coordinator that owns the trail: What's new hides without
/// being answered, comes back where it was, and every way out of
/// the trail ends the banner.
@MainActor
@Suite("What's new handoff (#2038)", .serialized)
struct WhatsNewHandoffTests {
    /// A census id this build lands on.
    private static func linkedID() throws -> String {
        try #require(
            SettingsSearchIndex.rows().compactMap(\.key?.id).first
        )
    }

    private final class Log {
        var fronted: [NSWindow] = []
        var hidden: [NSWindow] = []
        var trails: [WhatsNewTrail] = []
        var ended = 0
    }

    private static func coordinator() async throws -> (
        WhatsNewCoordinator, WhatsNewWindowController, WhatsNewRecord, Log
    ) {
        let notes = """
            {"format":1,"summary":"Intro.","sections":\
            [{"type":"new","title":"New","items":["N"]}],\
            "spotlight":[{"title":"Row","line":"L.",\
            "setting":"\(try linkedID())"}]}
            """
        let (coordinator, record, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: [
                .init(
                    version: "9999.2.0",
                    shown: "9999.2.0",
                    released: nil,
                    notes: notes
                )
            ]
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
        coordinator.endsTrail = { log.ended += 1 }
        await coordinator.launched(opensWindow: true, existingUser: true)
        return (coordinator, try #require(shown), record, log)
    }

    private static func row(
        _ controller: WhatsNewWindowController
    ) throws -> UpdateNotesDigest.SpotlightEntry {
        try #require(controller.offer.digest?.spotlight.first)
    }

    @Test("Show me hides What's new unanswered and hands Settings a trail")
    func showMeHides() async throws {
        let (coordinator, controller, record, log) =
            try await Self.coordinator()
        #expect(log.fronted.count == 1)
        #expect(!controller.hidden)
        coordinator.showMe(try Self.row(controller))
        #expect(controller.hidden)
        #expect(log.hidden.count == 1)
        #expect(log.hidden.first === log.fronted.first)
        #expect(log.trails.first?.current.title == "Row")
        // Not answered: the notes still wait, nothing recorded.
        #expect(coordinator.waiting != nil)
        #expect(record.lastRun == "9999.1.0")
    }

    /// The same controller and window, not re-centred: its place,
    /// tab and scroll are what the reader left.
    @Test("Back re-presents the same window where it was")
    func backReturns() async throws {
        let (coordinator, controller, _, log) =
            try await Self.coordinator()
        let window = try #require(log.fronted.first)
        window.setFrameOrigin(NSPoint(x: 7, y: 9))
        coordinator.showMe(try Self.row(controller))
        let ended = log.ended
        try #require(log.trails.first).back()
        #expect(log.fronted.count == 2)
        #expect(log.fronted.last === window)
        #expect(window.frame.origin == NSPoint(x: 7, y: 9))
        #expect(!controller.hidden)
        #expect(log.ended == ended + 1)
    }

    @Test("× finishes What's new and ends the trail")
    func dismissAnswers() async throws {
        let (coordinator, controller, record, log) =
            try await Self.coordinator()
        coordinator.showMe(try Self.row(controller))
        let ended = log.ended
        try #require(log.trails.first).dismiss()
        #expect(coordinator.waiting == nil)
        #expect(record.lastRun == "9999.2.0")
        #expect(log.ended == ended + 1)
    }

    /// The quick menu's row reopens the hidden window: the banner
    /// must not outlive it with a Back that leads nowhere new.
    @Test("re-presenting What's new while hidden ends the trail")
    func quickMenuEndsTrail() async throws {
        let (coordinator, controller, _, log) =
            try await Self.coordinator()
        coordinator.showMe(try Self.row(controller))
        let ended = log.ended
        coordinator.show()
        #expect(log.ended == ended + 1)
        #expect(!controller.hidden)
    }

    @Test("Settings closing re-presents What's new")
    func settingsCloseReshows() async throws {
        let (coordinator, controller, _, log) =
            try await Self.coordinator()
        coordinator.showMe(try Self.row(controller))
        try #require(log.trails.first).settingsClosed()
        #expect(log.fronted.count == 2)
        #expect(!controller.hidden)
    }

    @Test("Settings closing under an update window leaves it hidden")
    func settingsCloseYieldsToUpdateWindow() async throws {
        let (coordinator, controller, _, log) =
            try await Self.coordinator()
        coordinator.updateWindowOpen = { true }
        coordinator.showMe(try Self.row(controller))
        try #require(log.trails.first).settingsClosed()
        #expect(log.fronted.count == 1)
        #expect(controller.hidden)
        #expect(coordinator.waiting != nil)
    }
}

/// What a fixture cannot see: the close, the bootstrap and the
/// focus statement reaching the trail (#2038).
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

    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("the Settings window's close ends the trail")
    func settingsCloseReachesTheModel() throws {
        let body = try Self.body(
            of: "func windowWillClose(",
            in: "Settings/SettingsWindowController.swift"
        )
        #expect(body.contains("model.settingsClosed()"))
    }

    @Test("bootstrap wires the trail once, both halves")
    func bootstrapWiresTheTrail() throws {
        let launch = try Self.body(
            of: "func applicationDidFinishLaunching(",
            in: "AppDelegate.swift"
        )
        #expect(launch.contains("wireWhatsNewTrail()"))
        let wire = try Self.body(
            of: "func wireWhatsNewTrail(",
            in: "AppDelegate+WhatsNew.swift"
        )
        #expect(wire.contains("whatsNew.showsInSettings = {"))
        #expect(wire.contains("dashboard.follow(trail)"))
        #expect(wire.contains("whatsNew.endsTrail = {"))
        #expect(wire.contains("endWhatsNewTrail()"))
        let offer = try Self.body(
            of: "func offerWhatsNew(",
            in: "AppDelegate+WhatsNew.swift"
        )
        #expect(!offer.contains("showsInSettings"))
    }

    @Test("the updater tells What's new when an update window is up")
    func updaterWiresTheSlot() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: Self.gui.appendingPathComponent(
                    "Updates/AppUpdater.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(
            Self.squashed(source).contains(
                "whatsNew?.updateWindowOpen={[driver]indriver.current!=nil}"
            )
        )
    }

    /// The shell outlives the banner (#996) and the statement asks
    /// the recorded input source (#991).
    @Test("the shell states the trail's focus, gated on the input source")
    func shellStatesTrailFocus() throws {
        let source = Self.squashed(
            SourceScan.stripComments(
                try String(
                    contentsOf: Self.gui.appendingPathComponent(
                        "Settings/SettingsView.swift"
                    ),
                    encoding: .utf8
                )
            )
        )
        #expect(
            source.contains(
                ".onChange(of:model.nav.trailFocusRequest){_,_in"
                    + "ifmodel.destination!=nil,"
                    + "model.nav.navigationMovesFocus{"
                    + "contentFocused=true}}"
            )
        )
    }

    @Test("a bar menu's landing takes the one external door")
    func barLandingTakesTheDoor() throws {
        let body = try Self.body(
            of: "func show(landing: SettingsLanding) {",
            in: "Settings/SettingsWindowController.swift"
        )
        #expect(body.contains("model.land(on:"))
        #expect(!body.contains("pendingReveal"))
    }
}
