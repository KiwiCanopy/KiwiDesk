import Testing

@testable import KiwiDeskCore

/// What "Restore in every profile" takes from the other profiles
/// (#3248): `lostSharing` writes each seed as the Save does and
/// counts the rows of their own the others no longer resolve.
@Suite("Rows every profile's restore takes (#3248)")
struct RuleReachLostSharingTests {
    private let seed = "default\u{1F}seed()"
    private let mine = "default\u{1F}mine()"

    private func table(
        base: [String: String],
        entries: [String: [String: String?]]
    ) -> RuleReachTable<String> {
        RuleReachTable(
            base: base,
            entries: entries,
            profiles: ["Work", "Home", "Travel"]
        )
    }

    @Test("a row of Home's own on the seed's chord is lost")
    func ownRowOnTheChord() {
        let t = table(
            base: [seed: "alt+h"],
            entries: ["Home": [seed: "alt+j", mine: "alt+h"]]
        )
        #expect(t.lostSharing([seed: "alt+h"], editing: "Work") == ["Home": 1])
    }

    /// A row Home already leaves out resolves nothing, so nothing is
    /// lost there.
    @Test("a tombstoned row is not counted")
    func tombstoneIsNotCounted() {
        let t = table(
            base: [seed: "alt+h", mine: "alt+h"],
            entries: ["Home": [mine: String?.none]]
        )
        let lost = t.lostSharing([seed: "alt+h"], editing: "Work")
        #expect(lost["Home"] == nil)
    }

    /// A shared row on the chord leaves the base, so every profile that
    /// followed it loses it once.
    @Test("a shared row on the chord counts once per follower")
    func sharedRowCountsPerFollower() {
        let t = table(base: [seed: "alt+j", mine: "alt+h"], entries: [:])
        #expect(
            t.lostSharing([seed: "alt+h"], editing: "Work")
                == ["Home": 1, "Travel": 1]
        )
    }
}
