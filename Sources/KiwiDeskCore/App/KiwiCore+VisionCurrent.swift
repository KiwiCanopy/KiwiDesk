import Foundation

/// `kiwivision.current` (#2103, #1685 ▸ Ruling 2): what KiwiVision
/// draws now and the live settings, read through the same accessors
/// KiwiHub and Settings read — never a second derivation.
extension KiwiCore {
    /// Whether KiwiVision is on and the lens on, the plain look
    /// under `gui.json`'s `kiwivision` keys, and every live lens:
    /// its `define_lens` table, its refusal, and whether `gui.json`
    /// holds it as it is — absent for a Lua-owned setup, whose
    /// store is `init.lua` (ruling 40).
    func visionCurrent() -> JSONValue {
        let stored = kiwiVisionLensesInGuiJSON
        let lenses: [JSONValue] = appWide.visionLenses.map { lens in
            var row: [String: JSONValue] = [
                "lens": JSONValue(encoding: lens) ?? .null
            ]
            if let refusal = lensRefusal(lens) {
                row["refusal"] = Self.json(refusal)
            }
            if let stored { row["saved"] = .bool(stored.contains(lens)) }
            return .object(row)
        }
        var answer = visionState
        answer["settings"] =
            JSONValue(encoding: appWide.look(lens: nil).storedGroup)
            ?? .null
        answer["lenses"] = .array(lenses)
        return .object(answer)
    }

    /// Whether KiwiVision is on and the lens on, null for plain or
    /// off: what `toggle` answers and `current` opens with.
    var visionState: [String: JSONValue] {
        [
            "on": .bool(vision.isOn),
            "lens": visionLensName.map(JSONValue.string) ?? .null,
        ]
    }

    /// A refusal as structure: its reason, and the profile that
    /// leaves the lens out.
    private static func json(_ refusal: LensRefusal) -> JSONValue {
        switch refusal {
        case .noApps:
            return .object(["reason": .string("no_apps")])
        case .outOfReach(let profile):
            return .object([
                "reason": .string("out_of_reach"),
                "profile": .string(profile),
            ])
        }
    }
}
