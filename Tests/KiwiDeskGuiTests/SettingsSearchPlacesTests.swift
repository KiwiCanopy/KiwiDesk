import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The "Made by you" group (#678 spec 11a, `place` in code) and
/// the mode-switch notice:
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

    /// One entry per named object, landing on the area that
    /// owns its kind — derived from `Kind.allCases` with an
    /// exhaustive-switch context filler, so a future kind that
    /// compiles but never produces a result reds here instead
    /// of shipping silent (parity-tests.md, past-two-mirrors).
    @Test("each kind lands on its owning area")
    func kindsLandOnTheirAreas() {
        pinEnglish()
        defer { reset() }
        var context = SettingsSearchContext()
        for kind in SettingsSearchPlace.Kind.allCases {
            switch kind {
            case .space: context.spaces = ["mail"]
            case .profile: context.profiles = ["mail-desk"]
            case .appRule: context.appRules = ["Mail"]
            }
        }
        let hits = places("mail", context: context)
        #expect(
            hits.count
                == SettingsSearchPlace.Kind.allCases.count
        )
        let byKind = Dictionary(
            uniqueKeysWithValues: hits.map { ($0.kind, $0) }
        )
        // The expected side is HAND-PINNED per case, never
        // `kind.destination` — the builder constructs anchors
        // FROM that mapping, so asserting against it moves both
        // sides together and proves nothing (guard-prover found
        // the first cut inert, 2026-08-10; the exhaustive
        // switch still makes a new kind a compile error here).
        for kind in SettingsSearchPlace.Kind.allCases {
            let expected: SettingsDestination
            switch kind {
            case .space: expected = .spaces
            case .profile: expected = .profiles
            case .appRule: expected = .appRules
            }
            #expect(
                byKind[kind]?.anchor.destination == expected,
                Comment(rawValue: kind.rawValue)
            )
        }
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
        // The first `placesCap` matches won — order is the
        // input's, and the pin derives the number (#614).
        #expect(
            hits.map(\.name)
                == (1...SettingsSearch.placesCap)
                .map { "web \($0)" }
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
