import Foundation
import Testing

@testable import KiwiDeskCore

/// The keep document's leaves (#1685): a diff names the leaves a
/// command changed, a pointer survives a dot or a slash in a key,
/// and a patch writes a leaf back through the config's decoder.
@Suite("Keep pointers")
struct KeepPointerTests {
    private func object(_ members: [String: JSONValue]) -> JSONValue {
        .object(members)
    }

    @Test("a diff names leaves, never the groups holding them")
    func diffNamesLeaves() {
        let old = object([
            "gap": object(["inner": .number(4), "outer": .number(8)]),
            "list": .array([.number(1)]),
        ])
        let new = object([
            "gap": object(["inner": .number(6), "outer": .number(8)]),
            "list": .array([.number(1), .number(2)]),
        ])
        #expect(KeepPointer.diff(old, new) == [["gap", "inner"], ["list"]])
        #expect(KeepPointer.diff(old, old).isEmpty)
    }

    @Test("a group one side omits yields its leaves")
    func omittedGroupYieldsLeaves() {
        let old = object([:])
        let new = object(["gap": object(["inner": .number(6)])])
        #expect(KeepPointer.diff(old, new) == [["gap", "inner"]])
        #expect(KeepPointer.diff(new, old) == [["gap", "inner"]])
    }

    @Test("a pointer round-trips a dot, a slash and a tilde")
    func pointerEscapes() {
        let path = ["settings", "edge_override", "A:1.5/x~y"]
        let pointer = KeepPointer.string(path)
        #expect(pointer == "/settings/edge_override/A:1.5~1x~0y")
        #expect(KeepPointer.path(pointer) == path)
        #expect(KeepPointer.path("settings") == nil)
    }

    @Test("setting makes missing groups; nil removes the leaf")
    func settingWritesAndRemoves() {
        let root = object([:])
        let set = KeepPointer.setting(
            .number(3),
            at: ["a", "b"],
            in: root
        )
        #expect(KeepPointer.value(at: ["a", "b"], in: set) == .number(3))
        let removed = KeepPointer.setting(nil, at: ["a", "b"], in: set)
        #expect(KeepPointer.value(at: ["a", "b"], in: removed) == nil)
    }

    @Test("a patch writes a settings leaf through the decoder")
    func patchThroughDecoder() throws {
        var live = TilingSettings()
        live.borderStyle.width = 7
        let root = try #require(live.keepJSON)
        let changed = KeepPointer.diff(TilingSettings().keepJSON, root)
        #expect(!changed.isEmpty)
        var leaves: [[String]: JSONValue?] = [:]
        for path in changed {
            leaves[path] = .some(KeepPointer.value(at: path, in: root))
        }
        let patched = try #require(TilingSettings().patched(leaves))
        #expect(patched.borderStyle.width == 7)
        #expect(patched == live)
    }
}
