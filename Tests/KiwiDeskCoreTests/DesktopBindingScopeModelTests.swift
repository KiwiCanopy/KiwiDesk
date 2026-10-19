import Foundation
import Testing

@testable import KiwiDeskCore

/// A Desktop binding entry's scope (#1609): an entry is a
/// (profile, screen setup) pair, overlapping entries replace each
/// other, the gate's rank puts one scoped to the connected setup
/// first, and a bare name on disk still means all screen setups.
@Suite("Desktop binding scope: the record (#1609)")
struct DesktopBindingScopeModelTests {
    private let vision = ["Sidecar:3360x1440"]
    private let wide = ["Sidecar:5120x1440"]
    private let counts = ["Starter": 1, "Vision": 1, "Solo": 1, "Dual": 2]

    private func record() -> DesktopBinding {
        DesktopBinding(profiles: [], desktop: 1)
    }

    @Test("same count and scope replaces; another scope adds")
    func overlapReplaces() {
        var record = record()
        record.bind(.init(name: "Starter")) { counts[$0.name] }
        record.bind(.init(name: "Vision", setup: vision)) { counts[$0.name] }
        record.bind(.init(name: "Vision", setup: wide)) { counts[$0.name] }
        #expect(
            record.entries == [
                .init(name: "Starter"),
                .init(name: "Vision", setup: vision),
                .init(name: "Vision", setup: wide),
            ]
        )
        // Same count, all setups: replaces Starter only.
        record.bind(.init(name: "Solo")) { counts[$0.name] }
        // Same count, same setup: replaces that one entry only.
        record.bind(.init(name: "Starter", setup: wide)) { counts[$0.name] }
        #expect(
            record.entries == [
                .init(name: "Vision", setup: vision),
                .init(name: "Solo"),
                .init(name: "Starter", setup: wide),
            ]
        )
        // Another count never overlaps.
        record.bind(.init(name: "Dual")) { counts[$0.name] }
        #expect(record.entries.count == 4)
    }

    @Test("an unbind of one scope leaves the others")
    func unbindIsScoped() {
        var record = record()
        record.bind(.init(name: "Starter")) { counts[$0.name] }
        record.bind(.init(name: "Vision", setup: vision)) { counts[$0.name] }
        let scopedEmptied = record.unbind(count: 1, setup: vision) {
            counts[$0.name]
        }
        #expect(!scopedEmptied)
        #expect(record.entries == [.init(name: "Starter")])
        record.bind(.init(name: "Vision", setup: vision)) { counts[$0.name] }
        let allEmptied = record.unbind(count: 1) { counts[$0.name] }
        #expect(!allEmptied)
        #expect(
            record.entries == [.init(name: "Vision", setup: vision)]
        )
        let emptied = record.unbind(.pending("Vision"))
        #expect(emptied)
    }

    @Test("a rename keeps each entry's scope")
    func renameKeepsScope() {
        var record = record()
        record.bind(.init(name: "Vision", setup: vision)) { counts[$0.name] }
        record.bind(.init(name: "Vision")) { counts[$0.name] }
        record.relabel(nil, from: "Vision", to: "AVP")
        #expect(
            record.entries == [
                .init(name: "AVP", setup: vision),
                .init(name: "AVP"),
            ]
        )
        #expect(record.names == ["AVP"])
    }

    @Test("the rank: this setup's entries, then all setups'")
    func rankedTiers() {
        var record = record()
        record.bind(.init(name: "Starter")) { counts[$0.name] }
        record.bind(.init(name: "Dual")) { counts[$0.name] }
        record.bind(.init(name: "Vision", setup: vision)) { counts[$0.name] }
        record.bind(.init(name: "Solo", setup: wide)) { counts[$0.name] }
        #expect(
            record.ranked(for: vision, preferring: nil).map(\.name)
                == ["Vision", "Starter", "Dual"]
        )
        // The live profile leads ITS tier, never another's.
        #expect(
            record.ranked(
                for: vision,
                preferring: (ProfileID.legacy(name: "Dual"), "Dual")
            )
            .map(\.name) == ["Vision", "Dual", "Starter"]
        )
        #expect(
            record.ranked(for: ["Other:1x1"], preferring: nil)
                .map(\.name) == ["Starter", "Dual"]
        )
    }

    @Test("a bare name is all setups on disk; a scope is an object")
    func storedShape() throws {
        var record = record()
        record.bind(.init(name: "Starter")) { counts[$0.name] }
        record.bind(.init(name: "Vision", setup: ["B:1x1", "A:1x1"])) {
            counts[$0.name]
        }
        let data = try JSONEncoder().encode(record)
        let object = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        let entries = try #require(object["profiles"] as? [Any])
        #expect(entries.first as? String == "Starter")
        let scoped = try #require(entries.last as? [String: Any])
        #expect(scoped["profile"] as? String == "Vision")
        #expect(scoped["setup"] as? [String] == ["A:1x1", "B:1x1"])
        #expect(
            try JSONDecoder().decode(DesktopBinding.self, from: data)
                == record
        )
        // What every record written before #1609 looks like.
        let legacy = Data(#"{"profiles":["Work"],"desktop":2}"#.utf8)
        #expect(
            try JSONDecoder().decode(DesktopBinding.self, from: legacy)
                .entries == [.init(name: "Work")]
        )
    }

    @Test("a scoped entry naming no screens is refused")
    func emptyScopeRefused() {
        let data = Data(
            #"{"profiles":[{"profile":"V","setup":[]}],"desktop":1}"#.utf8
        )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(DesktopBinding.self, from: data)
        }
    }
}
