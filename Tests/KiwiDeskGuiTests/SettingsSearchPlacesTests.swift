import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Places group (#678 spec 11a) and the mode-switch notice:
/// the user's own named things as capped results, and the
/// one-line confirmation a Power-User pick leaves behind.
@Suite("Settings search places", .serialized)
@MainActor
struct SettingsSearchPlacesTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    private func places(
        _ query: String,
        context: SettingsSearchContext
    ) -> [SettingsSearchPlace] {
        SettingsSearch.results(query: query, context: context)
            .places
            .compactMap {
                guard case .place(let place) = $0 else {
                    return nil
                }
                return place
            }
    }

    /// One entry per named object, landing on the area that owns
    /// its kind.
    @Test("each kind lands on its owning area")
    func kindsLandOnTheirAreas() {
        pinEnglish()
        defer { reset() }
        let context = SettingsSearchContext(
            spaces: ["mail"],
            profiles: ["mail-desk"],
            palettes: ["mailbox"],
            appRules: ["Mail"]
        )
        let hits = places("mail", context: context)
        #expect(hits.count == 4)
        let byKind = Dictionary(
            uniqueKeysWithValues: hits.map { ($0.kind, $0) }
        )
        #expect(
            byKind[.space]?.anchor.destination == .spaces
        )
        #expect(
            byKind[.profile]?.anchor.destination == .profiles
        )
        #expect(
            byKind[.palette]?.anchor.destination == .colors
        )
        #expect(
            byKind[.appRule]?.anchor.destination == .appRules
        )
    }

    /// The cap counts MATCHES, not objects: seven matching
    /// spaces yield five rows, and the cap is the builder's
    /// `placesCap` — asserted by arithmetic against an input
    /// built past it, not by a scan for the constant.
    @Test("the places group is capped after matching")
    func capAppliesAfterMatching() {
        pinEnglish()
        defer { reset() }
        let context = SettingsSearchContext(
            spaces: (1...7).map { "web \($0)" }
        )
        let hits = places("web", context: context)
        #expect(hits.count == SettingsSearch.placesCap)
        // The first five matches won — order is the input's.
        #expect(
            hits.map(\.name)
                == (1...5).map { "web \($0)" }
        )
    }

    @Test("place matching shares the one predicate")
    func placeMatchingIsDiacriticInsensitive() {
        pinEnglish()
        defer { reset() }
        let context = SettingsSearchContext(
            spaces: ["Größe"]
        )
        #expect(
            places("grosse", context: context).count == 1
        )
    }

    /// The confirmation line (#678 4c): set with the flipped
    /// destination's title in it, superseded by a second flip,
    /// and self-clearing — the only place search mentions the
    /// mode.
    @Test("the mode-switch notice names the destination")
    func modeNoticeNamesDestination() async {
        pinEnglish()
        defer { reset() }
        let model = makeTestModel()
        #expect(model.searchModeNotice == nil)
        model.noteSearchModeSwitch(.advancedColors)
        let notice = model.searchModeNotice
        #expect(notice != nil)
        #expect(
            notice?.contains("Advanced Colors") == true
        )
        // A second flip supersedes the first.
        model.noteSearchModeSwitch(.behavior)
        #expect(
            model.searchModeNotice?.contains("Behavior") == true
        )
        model.searchNoticeTask?.cancel()
    }

    /// The self-clear half, previously unguarded: guard-prover
    /// (2026-08-10) showed the clear task could be deleted with
    /// this suite green. A generous hang-guard poll, never a
    /// tight deadline (#344): the notice clears at ~5 s, the
    /// poll exits the moment it does, and the 30 s bound only
    /// catches a genuine never-clears.
    @Test("the mode-switch notice clears itself")
    func modeNoticeSelfClears() async throws {
        pinEnglish()
        defer { reset() }
        let model = makeTestModel()
        model.noteSearchModeSwitch(.advancedColors)
        #expect(model.searchModeNotice != nil)
        let deadline = ContinuousClock.now + .seconds(30)
        while model.searchModeNotice != nil,
            ContinuousClock.now < deadline
        {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(model.searchModeNotice == nil)
    }
}
