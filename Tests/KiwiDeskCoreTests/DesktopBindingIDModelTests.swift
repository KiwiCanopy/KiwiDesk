import Foundation
import Testing

@testable import KiwiDeskCore

/// The binding record's id algebra (#2324 ruling 11): an entry is
/// what it NAMES and its scope, never its label; a rename relabels,
/// a promotion gives a pending entry its id, and the live profile is
/// told apart by id, never by a label that happens to match.
@Suite("Desktop binding id algebra (#2324)")
struct DesktopBindingIDModelTests {
    private let work = ProfileID.legacy(name: "Work")
    private let other = ProfileID.legacy(name: "Other")

    private func record(_ entries: DesktopBinding.Entry...) -> DesktopBinding {
        DesktopBinding(entries: entries, desktop: 1)
    }

    @Test("An entry is its id and scope, never its label")
    func labelIsNotIdentity() {
        let a = DesktopBinding.Entry(id: work, name: "Work")
        let b = DesktopBinding.Entry(id: work, name: "Office")
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
        #expect(a != DesktopBinding.Entry(name: "Work"))
        #expect(
            a != DesktopBinding.Entry(id: work, name: "Work", setup: ["A"])
        )
    }

    @Test("A re-bind refreshes the label in place")
    func bindRefreshesTheLabel() {
        var binding = record(.init(id: work, name: "Work"))
        binding.bind(.init(id: work, name: "Office")) { _ in 1 }
        #expect(binding.entries.count == 1)
        #expect(binding.entries[0].name == "Office")
    }

    @Test("An unbind by id leaves a pending entry of that name")
    func unbindByID() {
        var binding = record(
            .init(id: work, name: "Work"),
            .init(name: "Work", setup: ["A"])
        )
        binding.unbind(.id(work))
        #expect(binding.entries == [.init(name: "Work", setup: ["A"])])
    }

    @Test("A rename relabels the id and follows a pending name")
    func relabel() {
        var binding = record(
            .init(id: work, name: "Work"),
            .init(name: "Work", setup: ["A"]),
            .init(id: other, name: "Work", setup: ["B"])
        )
        binding.relabel(work, from: "Work", to: "Office")
        #expect(binding.entries.map(\.name) == ["Office", "Office", "Work"])
    }

    @Test("A promotion gives a pending entry its id, label kept")
    func promote() {
        var binding = record(.init(name: "Work"), .init(name: "Nobody"))
        let changed = binding.promote { $0 == "Work" ? work : nil }
        #expect(changed)
        #expect(binding.entries[0].id == work)
        #expect(binding.entries[0].name == "Work")
        #expect(binding.entries[1].id == nil)
        #expect(!binding.promote { _ in nil })
    }

    @Test("A label refresh follows the profile's current name")
    func refreshLabels() {
        var binding = record(.init(id: work, name: "Work"), .init(name: "P"))
        #expect(binding.refreshLabels { $0 == work ? "Office" : nil })
        #expect(binding.entries.map(\.name) == ["Office", "P"])
        #expect(!binding.refreshLabels { $0 == work ? "Office" : nil })
    }

    /// A stale label equal to the live name under another id is not
    /// the live profile; a pending entry is, by name.
    @Test("The live profile is told apart by id")
    func liveByID() {
        let live = (id: work, name: "Work")
        #expect(DesktopBinding.names(.init(id: work, name: "Old"), live))
        #expect(!DesktopBinding.names(.init(id: other, name: "Work"), live))
        #expect(DesktopBinding.names(.init(name: "Work"), live))
    }

    /// The stored shape: `{id, name, setup?}` with an id, the pre-id
    /// shapes without one — asserted on the label as well, since
    /// equality cannot see it.
    @Test("An id entry stores its id, label and scope")
    func storedShape() throws {
        let entries: [DesktopBinding.Entry] = [
            .init(id: work, name: "Work"),
            .init(id: other, name: "Other", setup: ["A:1x1"]),
            .init(name: "Pending"),
        ]
        let data = try JSONEncoder().encode(entries)
        let raw = try #require(
            JSONSerialization.jsonObject(with: data) as? [Any]
        )
        let first = try #require(raw[0] as? [String: Any])
        #expect(first["id"] as? String == work.raw)
        #expect(first["name"] as? String == "Work")
        #expect(first["setup"] == nil)
        #expect(raw[2] as? String == "Pending")
        let back = try JSONDecoder().decode(
            [DesktopBinding.Entry].self,
            from: data
        )
        #expect(back.map(\.name) == ["Work", "Other", "Pending"])
        #expect(back.map(\.id) == [work, other, nil])
        #expect(back.map(\.setup) == [nil, ["A:1x1"], nil])
    }
}
