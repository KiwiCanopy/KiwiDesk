import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("RuleListOverride (#287)")
struct RuleListOverrideTests {
    private let identity: (String) -> String = { $0 }

    @Test("Empty override inherits normalized base")
    func emptyInherits() {
        let result = RuleListOverride().resolved(
            onto: ["Mail", "Mail", "Music"],
            normalizing: identity
        )
        #expect(result == ["Mail", "Music"])
    }

    @Test("Adds sorted rules and removes inherited rules")
    func addAndRemove() {
        var rules: [String: Bool?] = [
            "Zulu": true,
            "Alpha": true,
        ]
        rules.updateValue(nil, forKey: "Music")
        let result = RuleListOverride(rules: rules).resolved(
            onto: ["Mail", "Music"],
            normalizing: identity
        )
        #expect(result == ["Mail", "Alpha", "Zulu"])
    }

    @Test("Normalizer supplies case-insensitive identity")
    func caseInsensitiveIdentity() {
        var rules: [String: Bool?] = ["TERMINAL": true]
        rules.updateValue(nil, forKey: "MAIL")
        let result = RuleListOverride(rules: rules).resolved(
            onto: ["Mail", "Safari"],
            normalizing: { $0.lowercased() }
        )
        #expect(result == ["safari", "terminal"])
    }

    @Test("Float normalizer can preserve title case")
    func titlePreservingNormalizer() {
        let normalize: (String) -> String = { rule in
            let parts = rule.split(
                separator: ":",
                maxSplits: 1
            )
            guard parts.count == 2 else {
                return rule.lowercased()
            }
            return parts[0].lowercased() + ":" + parts[1]
        }
        var rules: [String: Bool?] = [
            "COM.EXAMPLE:settings": true
        ]
        rules.updateValue(
            nil,
            forKey: "COM.EXAMPLE:Settings"
        )
        let result = RuleListOverride(
            rules: rules
        ).resolved(
            onto: ["com.example:Settings"],
            normalizing: normalize
        )
        #expect(
            result == ["com.example:settings"]
        )
    }

    @Test("Bare JSON round-trips additions and null tombstones")
    func codingRoundTrip() throws {
        let json = #"{"Terminal":true,"Music":null}"#
        let decoded = try JSONDecoder().decode(
            RuleListOverride.self,
            from: Data(json.utf8)
        )
        #expect(decoded.rules["Terminal"] == true)
        #expect(decoded.rules["Music"] == .some(nil))

        let data = try JSONEncoder().encode(decoded)
        let object = try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        #expect(object["Terminal"] as? Bool == true)
        #expect(object["Music"] is NSNull)
        let roundTrip = try JSONDecoder().decode(
            RuleListOverride.self,
            from: data
        )
        #expect(roundTrip == decoded)
    }

    @Test("False and empty entries are sanitized")
    func sanitizesFalseAndEmpty() throws {
        let decoded = try JSONDecoder().decode(
            RuleListOverride.self,
            from: Data(#"{"":true,"No":false,"Yes":true}"#.utf8)
        )
        #expect(decoded.rules == ["Yes": true])

        var mutated = RuleListOverride(rules: [
            "": true,
            "No": false,
        ])
        #expect(mutated.isEmpty)
        mutated.rules["Later"] = false
        let data = try JSONEncoder().encode(mutated)
        let object = try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        #expect(object.isEmpty)
    }

    @Test("No divergence produces nil diff")
    func inheritedDiffIsNil() {
        let result = RuleListOverride.diff(
            base: ["Mail", "Music"],
            edited: ["music", "mail"],
            normalizing: { $0.lowercased() }
        )
        #expect(result == nil)
    }

    @Test("Diff resolves back to edited rule set")
    func diffResolveInverse() throws {
        let base = ["Mail", "Music"]
        let edited = ["Mail", "Safari", "Calendar"]
        let override = try #require(
            RuleListOverride.diff(
                base: base,
                edited: edited,
                normalizing: identity
            )
        )
        #expect(override.rules["Music"] == .some(nil))
        #expect(override.rules["Safari"] == true)
        #expect(override.rules["Calendar"] == true)
        #expect(
            override.resolved(
                onto: base,
                normalizing: identity
            ) == ["Mail", "Calendar", "Safari"]
        )
    }

    @Test("Stale tombstone is inert and reactivates with base")
    func staleTombstone() {
        var rules: [String: Bool?] = [:]
        rules.updateValue(nil, forKey: "TERMINAL")
        let override = RuleListOverride(rules: rules)
        let normalize: (String) -> String = { $0.lowercased() }

        #expect(
            override.resolved(
                onto: ["mail"],
                normalizing: normalize
            ) == ["mail"]
        )
        #expect(
            override.resolved(
                onto: ["Mail", "Terminal"],
                normalizing: normalize
            ) == ["mail"]
        )
    }
}
