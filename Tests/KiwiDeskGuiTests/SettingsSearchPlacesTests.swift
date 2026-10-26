import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The "Made by you" group (#678 spec 11a, `place` in code): the
/// user's own named things as capped results.
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
            case .palette: context.palettes = ["Mail tones"]
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
            case .palette: expected = .looks
            }
            #expect(
                byKind[kind]?.anchor.destination == expected,
                Comment(rawValue: kind.rawValue)
            )
        }
    }

    /// `placeResults` applies no reachability filter on the
    /// stated premise that every place kind lands on a
    /// destination #18 never hides — held as a shape clause, so
    /// a kind landing on General owes the filter back.
    @Test("every place kind lands where a stored-profile edit reaches")
    func kindsStayReachable() {
        for kind in SettingsSearchPlace.Kind.allCases {
            #expect(
                kind.destination.isReachable(
                    editingStoredProfile: true
                ),
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
}
