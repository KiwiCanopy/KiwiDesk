import Foundation
import Testing

@testable import KiwiDeskCore

/// The Hyper key's `hidutil` remap (#1870): the plan, the parse
/// of `hidutil`'s own output, and the ownership rule — KiwiDesk
/// touches a mapping only where it is exactly what KiwiDesk
/// recorded writing.
@Suite("Hyper key remap")
struct HyperKeyRemapTests {
    private typealias Pair = HyperKeyRemap.Pair

    private let caps = HyperKeyRemap.pair(for: .capsLock)

    @Test("an empty mapping takes the wanted entry")
    func emptySets() {
        #expect(
            HyperKeyRemap.plan(current: [], written: nil, want: .capsLock)
                == .set(caps)
        )
        #expect(
            HyperKeyRemap.plan(current: [], written: nil, want: nil)
                == HyperKeyRemap.Plan.none
        )
    }

    @Test("KiwiDesk's own entry is replaced or cleared")
    func oursIsReplaced() {
        let right = HyperKeyRemap.pair(for: .rightCommand)
        #expect(
            HyperKeyRemap.plan(
                current: [caps],
                written: caps,
                want: .rightCommand
            ) == .set(right)
        )
        #expect(
            HyperKeyRemap.plan(current: [caps], written: caps, want: nil)
                == .clear
        )
        #expect(
            HyperKeyRemap.plan(
                current: [caps],
                written: caps,
                want: .capsLock
            ) == HyperKeyRemap.Plan.none
        )
    }

    @Test("an entry KiwiDesk did not record is never touched")
    func foreignIsRefused() {
        // Caps Lock → F18 is a common Hammerspoon mapping: the
        // shape alone is not ownership.
        #expect(
            HyperKeyRemap.plan(current: [caps], written: nil, want: nil)
                == .refuse
        )
        let other = Pair(source: 0x7_0000_0039, destination: 0x7_0000_0029)
        #expect(
            HyperKeyRemap.plan(
                current: [other],
                written: caps,
                want: .capsLock
            ) == .refuse
        )
        #expect(
            HyperKeyRemap.plan(
                current: [caps, other],
                written: caps,
                want: nil
            ) == .refuse
        )
    }

    @Test("a key mapped onto itself is no one's mapping")
    func identityIsNoOnesMapping() {
        // Hyperkey leaves Caps Lock → Caps Lock on the built-in
        // keyboard beside its Caps Lock → F18 (#2471 on device).
        let same = Pair(source: caps.source, destination: caps.source)
        #expect(
            HyperKeyRemap.plan(
                current: [caps, same],
                written: caps,
                want: .capsLock
            ) == .set(caps)
        )
        #expect(
            HyperKeyRemap.plan(current: [same], written: nil, want: nil)
                == HyperKeyRemap.Plan.none
        )
        #expect(
            HyperKeyRemap.foreign(in: [caps, same], want: .capsLock)
                == HyperForeignRemap(
                    source: .capsLock,
                    destination: .f18,
                    claimable: true
                )
        )
    }

    @Test("F18 itself needs no remap")
    func f18NeedsNone() {
        #expect(
            HyperKeyRemap.plan(current: [], written: nil, want: .f18)
                == HyperKeyRemap.Plan.none
        )
    }

    @Test("hidutil's listing parses in either key order")
    func listingParses() {
        let listing = """
            RegistryID  Key                   Value
            100000baa   UserKeyMapping   (null)
            1000007ee   UserKeyMapping   (
                    {
                    HIDKeyboardModifierMappingDst = 30064771181;
                    HIDKeyboardModifierMappingSrc = 30064771129;
                }
            )
            1000009fd   UserKeyMapping   (
                    {
                    HIDKeyboardModifierMappingSrc = 30064771129;
                    HIDKeyboardModifierMappingDst = 30064771181;
                }
            )
            10000090e   UserKeyMapping   (
            )
            """
        #expect(HyperKeyRemap.pairs(inHidutilOutput: listing) == [caps])
        // macOS 27's own order alone, with no Src-first twin.
        let dstFirst = """
            1   UserKeyMapping   (
                    {
                    HIDKeyboardModifierMappingDst = 30064771181;
                    HIDKeyboardModifierMappingSrc = 30064771129;
                }
            )
            """
        #expect(HyperKeyRemap.pairs(inHidutilOutput: dstFirst) == [caps])
        #expect(
            HyperKeyRemap.pairs(
                inHidutilOutput: "1   UserKeyMapping   (null)"
            ).isEmpty
        )
    }

    @Test("the set argument is hidutil's JSON")
    func setArgument() throws {
        let text = try #require(
            HyperKeyRemap.setArgument(for: .set(caps))
        )
        let root = try #require(
            try JSONSerialization.jsonObject(with: Data(text.utf8))
                as? [String: [[String: UInt64]]]
        )
        let entry: [String: UInt64] = [
            "HIDKeyboardModifierMappingSrc": 0x7_0000_0039,
            "HIDKeyboardModifierMappingDst": 0x7_0000_006D,
        ]
        #expect(root["UserKeyMapping"] == [entry])
        #expect(
            HyperKeyRemap.setArgument(for: .clear)
                == #"{"UserKeyMapping":[]}"#
        )
        #expect(HyperKeyRemap.setArgument(for: .refuse) == nil)
    }

    @Test("every source names its key code and back")
    func keyCodesRoundTrip() {
        for key in HyperSourceKey.allCases {
            #expect(HyperSourceKey(keyCode: key.keyCode) == key)
        }
        #expect(HyperSourceKey(keyCode: 4) == nil)  // H types
        #expect(HyperSourceKey.rightCommand.kind == .modifier(right: true))
        #expect(HyperSourceKey.f13.kind == .spare)
    }
}

/// The ownership record outlives a crash but not the mapping it
/// names: a record from another boot session is no record (#1870).
@Suite("Hyper key remap record")
struct HyperKeyRemapRecordTests {
    private let caps = HyperKeyRemap.pair(for: .capsLock)

    @Test("a record from this boot names its entry")
    func sameBootReads() {
        let stored = HyperKeyRemap.record(caps, boot: "A")
        #expect(HyperKeyRemap.recorded(stored, boot: "A") == caps)
    }

    @Test("a record from another boot names nothing")
    func otherBootIsAbsent() {
        let stored = HyperKeyRemap.record(caps, boot: "A")
        #expect(HyperKeyRemap.recorded(stored, boot: "B") == nil)
        #expect(HyperKeyRemap.recorded(stored, boot: nil) == nil)
        #expect(HyperKeyRemap.recorded(nil, boot: "A") == nil)
        #expect(HyperKeyRemap.recorded(["boot": "A"], boot: "A") == nil)
    }

    @Test("this boot has a session id")
    func bootSessionReads() {
        #expect(HyperKeyRemap.bootSession()?.isEmpty == false)
    }
}
