import Foundation
import Testing

@testable import KiwiDeskCore

/// Unit tests for the sparse per-profile app→space rule
/// override (#109): resolve semantics (add / change /
/// tombstone), `diff` as the exact inverse of `resolved`, the
/// transparent null-tombstone coding, and the `Profile` field
/// shape — the round-trip + resolve parity guard AGENTS.md §5
/// requires for a behavior-override tier.
@Suite("AppRuleOverride (#109)")
struct AppRuleOverrideTests {

    private let base: [String: SpaceID] = [
        "Mail": SpaceID(1),
        "Music": SpaceID(2),
    ]

    // MARK: - Resolve

    @Test("Empty/nil override inherits the base unchanged")
    func emptyInherits() {
        let normalized = [
            "mail": SpaceID(1),
            "music": SpaceID(2),
        ]
        #expect(
            ConfigResolver.resolvedAppRules(
                base: base,
                profile: nil
            ) == normalized
        )
        #expect(
            AppRuleOverride().resolved(onto: base) == normalized
        )
    }

    @Test("Override adds, changes, and tombstones per app")
    func resolveMerges() {
        let over = AppRuleOverride(rules: [
            // Change a base pin…
            "Mail": SpaceID(3),
            // …add a new one…
            "Safari": SpaceID(4),
            // …and un-pin a base app (tombstone).
            "Music": nil,
        ])
        let resolved = over.resolved(onto: base)
        #expect(resolved["mail"] == SpaceID(3))
        #expect(resolved["safari"] == SpaceID(4))
        #expect(resolved["music"] == nil)
        #expect(resolved.count == 2)
    }

    // MARK: - Diff (inverse of resolved)

    @Test("diff is the inverse of resolved")
    func diffInverse() throws {
        let edited: [String: SpaceID] = [
            "Mail": SpaceID(3),
            "Safari": SpaceID(4),
            // Music un-pinned.
        ]
        let over = AppRuleOverride.diff(
            base: base,
            edited: edited
        )
        #expect(
            over?.resolved(onto: base)
                == AppRuleOverride.normalized(edited)
        )
        // Shape: sparse — one change, one add, one tombstone.
        let rules = try #require(over).rules
        #expect(rules.count == 3)
        #expect(rules["mail"] == SpaceID(3))
        #expect(rules["safari"] == SpaceID(4))
        #expect(rules["music"] == .some(nil))
    }

    @Test("No divergence diffs to nil (never persisted empty)")
    func identicalDiffIsNil() {
        #expect(
            AppRuleOverride.diff(base: base, edited: base)
                == nil
        )
    }

    @Test("Mixed-case tombstone removes inherited app")
    func mixedCaseTombstone() {
        let over = AppRuleOverride(rules: ["MAIL": nil])

        let resolved = over.resolved(onto: base)

        #expect(resolved["mail"] == nil)
        #expect(resolved["music"] == SpaceID(2))
    }

    // MARK: - Coding

    @Test("Round-trips through JSON with a null tombstone")
    func codingRoundTrip() throws {
        let over = AppRuleOverride(rules: [
            "Safari": SpaceID(4),
            "Music": nil,
        ])
        let data = try JSONEncoder().encode(over)
        let json = try #require(
            String(data: data, encoding: .utf8)
        )
        // The tombstone is a bare JSON null, not a dropped key.
        #expect(json.contains("\"Music\":null"))
        let back = try JSONDecoder().decode(
            AppRuleOverride.self,
            from: data
        )
        #expect(back == over)
    }

    @Test("Decode drops empty app and space names (#31)")
    func decodeSanitizes() throws {
        let json = #"{"": "1", "Mail": "", "Music": null}"#
        let over = try JSONDecoder().decode(
            AppRuleOverride.self,
            from: Data(json.utf8)
        )
        #expect(over.rules.count == 1)
        #expect(over.rules["Music"] == .some(nil))
    }

    // MARK: - Profile field

    @Test("Profile JSON round-trips app_rules")
    func profileRoundTrip() throws {
        var profile = Profile(
            name: "Work",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings()
        )
        profile.appRules = AppRuleOverride(rules: [
            "Mail": SpaceID(3),
            "Music": nil,
        ])
        let data = try JSONEncoder().encode(profile)
        let json = try #require(
            String(data: data, encoding: .utf8)
        )
        // One vocabulary (§5): the profile key matches the
        // sidecar's `app_rules`.
        #expect(json.contains("\"app_rules\""))
        let back = try JSONDecoder().decode(
            Profile.self,
            from: data
        )
        #expect(back.appRules == profile.appRules)
    }

    @Test("No override: key absent, legacy profiles decode nil")
    func profileSparseEncoding() throws {
        let profile = Profile(
            name: "Work",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings()
        )
        let data = try JSONEncoder().encode(profile)
        let json = try #require(
            String(data: data, encoding: .utf8)
        )
        #expect(!json.contains("app_rules"))
        let back = try JSONDecoder().decode(
            Profile.self,
            from: data
        )
        #expect(back.appRules == nil)
    }
}
