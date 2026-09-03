import Foundation
import Testing

@testable import KiwiDeskCore

/// The plist walk, fed a dictionary rather than the host's
/// WindowServer (#1147) — which is the whole reason it was split
/// out of `allSpaces()`. Pure: no SkyLight, no overrides.
@Suite("Native space parse (#1147)")
struct NativeSpaceParseTests {
    private func display(
        _ uuid: String,
        current: UInt64?,
        spaces: [[String: Any]]
    ) -> [String: Any] {
        var out: [String: Any] = [
            "Display Identifier": uuid,
            "Spaces": spaces,
        ]
        if let current {
            out["Current Space"] = ["id64": current]
        }
        return out
    }

    @Test("a stamped Desktop carries its identity out")
    func readsTheStamp() throws {
        let spaces = NativeSpaces.parse([
            display(
                "UUID-A",
                current: 1,
                spaces: [
                    ["id64": UInt64(1), "type": 0],
                    [
                        "id64": UInt64(4), "type": 0,
                        DesktopIdentity.plistKey: "STAMP-4",
                    ],
                ]
            )
        ])
        #expect(spaces.count == 2)
        #expect(spaces[0].identity == nil)
        #expect(spaces[0].isCurrent)
        #expect(
            spaces[1].identity == DesktopIdentity(raw: "STAMP-4")
        )
        #expect(!spaces[1].isCurrent)
    }

    /// Only the identity key is this read's business: the store
    /// is Apple's own dictionary and other `kiwidesk.` entries
    /// belong to something else — the 2026-08-18 probe stamp is
    /// still on a real Desktop and must not read as an identity.
    @Test("another kiwidesk key is not an identity")
    func ignoresOtherKiwiKeys() {
        let spaces = NativeSpaces.parse([
            display(
                "UUID-A",
                current: nil,
                spaces: [
                    [
                        "id64": UInt64(1), "type": 0,
                        "kiwidesk.probe.stamp": "set-2026-08-18",
                    ]
                ]
            )
        ])
        #expect(spaces.first?.identity == nil)
    }

    /// An empty string is not an identity — a stamp write that
    /// half-landed must read as unstamped, so the next snapshot
    /// re-stamps rather than filing state under "".
    @Test("an empty stamp reads as unstamped")
    func emptyStampIsNoIdentity() {
        let spaces = NativeSpaces.parse([
            display(
                "UUID-A",
                current: nil,
                spaces: [
                    [
                        "id64": UInt64(1), "type": 0,
                        DesktopIdentity.plistKey: "",
                    ]
                ]
            )
        ])
        #expect(spaces.first?.identity == nil)
    }

    /// Position is the Mission Control order and the ids are not
    /// sorted — the device reads 1, 4, 3, 5 for Desktops 1–4.
    /// A fullscreen space (`type != 0`) sits in the array and is
    /// not a user Desktop.
    @Test("position is the numbering, not the id")
    func positionIsTheNumbering() {
        let spaces = NativeSpaces.parse([
            display(
                "UUID-A",
                current: nil,
                spaces: [
                    ["id64": UInt64(1), "type": 0],
                    ["id64": UInt64(4), "type": 0],
                    ["id64": UInt64(9), "type": 4],
                    ["id64": UInt64(3), "type": 0],
                ]
            )
        ])
        #expect(spaces.map(\.id) == [1, 4, 9, 3])
        #expect(spaces.map(\.isUser) == [true, true, false, true])
        #expect(NativeSpaces.number(of: 3, in: spaces) == 3)
        #expect(NativeSpaces.number(of: 9, in: spaces) == nil)
    }

    /// A space with no id is skipped rather than filed as zero.
    @Test("a space with no id is skipped")
    func skipsIdlessSpaces() {
        let spaces = NativeSpaces.parse([
            display(
                "UUID-A",
                current: nil,
                spaces: [["type": 0], ["id64": UInt64(2), "type": 0]]
            )
        ])
        #expect(spaces.map(\.id) == [2])
    }
}
