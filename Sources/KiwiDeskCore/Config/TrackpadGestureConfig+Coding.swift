import Foundation

/// The wire shape (#1873): `{ "tap4": { "lua": …, "modifiers":
/// "control+option" }, "swipe3": { "family": "focus", … },
/// "tap3": null }`. A swipe slot stores its family under `family`,
/// every other slot its Lua under `lua`, the key a migration
/// rewriting stored Lua already matches in shortcut rows. A slot the
/// object leaves out inherits and `null` is the tombstone; an
/// unknown slot name fails the decode, as every stored value's does.
extension TrackpadGestureMap: Codable {
    private struct SlotKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    private enum BindingKeys: String, CodingKey {
        case lua, family, modifiers
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: SlotKey.self)
        var entries: [TrackpadGestureSlot: TrackpadGestureEntry] = [:]
        for key in c.allKeys {
            guard let slot = TrackpadGestureSlot(rawValue: key.stringValue)
            else {
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: c,
                    debugDescription: "unknown gesture slot"
                )
            }
            if try c.decodeNil(forKey: key) {
                entries[slot] = .unbound
                continue
            }
            let b = try c.nestedContainer(
                keyedBy: BindingKeys.self,
                forKey: key
            )
            entries[slot] = .bound(
                TrackpadGestureBinding(
                    action: try b.decode(
                        String.self,
                        forKey: slot.isSwipe ? .family : .lua
                    ),
                    modifiers: try b.decodeIfPresent(
                        ScrollChord.self,
                        forKey: .modifiers
                    ) ?? []
                )
            )
        }
        self.init(entries)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: SlotKey.self)
        for slot in TrackpadGestureSlot.allCases {
            let key = SlotKey(stringValue: slot.rawValue)
            switch entries[slot] {
            case nil: continue
            case .unbound: try c.encodeNil(forKey: key)
            case .bound(let binding):
                var b = c.nestedContainer(
                    keyedBy: BindingKeys.self,
                    forKey: key
                )
                try b.encode(
                    binding.action,
                    forKey: slot.isSwipe ? .family : .lua
                )
                try b.encode(binding.modifiers, forKey: .modifiers)
            }
        }
    }
}
