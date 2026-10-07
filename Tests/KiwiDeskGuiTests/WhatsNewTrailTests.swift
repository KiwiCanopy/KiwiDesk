import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The trail as a value and as Settings draws it (#2038 ruling ▸
/// handoff): Next walks the linked rows, and ×, Back and the
/// Settings close each end the banner. The window's half is
/// `WhatsNewHandoffTests`.
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

    final class Log {
        var back = 0
        var dismissed = 0
        var closed = 0
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
            dismiss: { log.dismissed += 1 },
            settingsClosed: { log.closed += 1 }
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
        let before = model.nav.trailFocusRequest
        model.followNext()
        #expect(model.whatsNewTrail?.current.title == "B")
        #expect(model.nav.pendingReveal?.anchor == "b")
        // Next states the newly landed control (#991).
        #expect(model.nav.trailFocusRequest == before + 1)
        // On the last row Next is absent: no landing, no statement.
        model.followNext()
        #expect(model.nav.trailFocusRequest == before + 1)
    }

    @Test("× clears the banner, finishes What's new, states focus")
    func dismissEnds() throws {
        let log = Log()
        let model = model(with: try #require(Self.trail(log: log)))
        let before = model.nav.trailFocusRequest
        model.dismissWhatsNew()
        #expect(model.whatsNewTrail == nil)
        #expect(log.dismissed == 1)
        #expect(log.back == 0)
        #expect(model.nav.trailFocusRequest == before + 1)
    }

    /// Back states nothing in Settings: the focus goes with What's
    /// new's window, which the coordinator fronts.
    @Test("Back clears the banner and returns to What's new")
    func backEnds() throws {
        let log = Log()
        let model = model(with: try #require(Self.trail(log: log)))
        let before = model.nav.trailFocusRequest
        model.returnToWhatsNew()
        #expect(model.whatsNewTrail == nil)
        #expect(log.back == 1)
        #expect(log.dismissed == 0)
        #expect(model.nav.trailFocusRequest == before)
    }

    @Test("closing Settings clears the banner and tells the owner")
    func settingsCloseEnds() throws {
        let log = Log()
        let model = model(with: try #require(Self.trail(log: log)))
        model.settingsClosed()
        #expect(model.whatsNewTrail == nil)
        #expect(log.closed == 1)
        #expect(log.back == 0)
        // Once: a second close has no trail to answer.
        model.settingsClosed()
        #expect(log.closed == 1)
    }

    // MARK: - The one external-landing door

    /// Armed on every landing: the reveal announces only a flip it
    /// made, on the destination it resolved
    /// (`WhatsNewTrailWiringTests` ▸ `revealAnnouncesResolved`).
    @Test("a landing arms the reveal and the mode notice")
    func landingArmsRevealAndNotice() {
        let model = makeTestModel()
        model.land(on: SettingsAnchor(destination: .shortcuts))
        #expect(model.nav.pendingModeNotice == .shortcuts)
        #expect(model.nav.pendingReveal?.destination == .shortcuts)
    }
}
