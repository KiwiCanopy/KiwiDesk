import Foundation

/// `kiwivision.current` (#2103, #1685 ▸ Ruling 2): what KiwiVision
/// draws now and the live settings, read through the same accessors
/// KiwiHub and Settings read — never a second derivation.
extension KiwiCore {
    /// Whether KiwiVision is on, the lens on, the plain settings as
    /// `gui.json`'s `kiwivision` group stores them, and every live
    /// lens as its `define_lens` table with its refusal and whether
    /// `gui.json` holds it as it is (ruling 40).
    func visionCurrent() -> JSONValue {
        var plain = appWide.vision
        plain.lenses = nil
        let stored = kiwiVisionStoredLenses
        let lenses: [JSONValue] = appWide.visionLenses.map { lens in
            guard case .object(var table) = Self.json(lens) else {
                return .null
            }
            if let refusal = lensRefusal(lens) {
                table["refusal"] = Self.json(refusal)
            }
            table["saved"] = .bool(stored.contains(lens))
            return .object(table)
        }
        let active = kiwiVisionActive
        return .object([
            "on": .bool(active.isOn),
            "lens": active.lensName.map(JSONValue.string) ?? .null,
            "plain": Self.json(plain),
            "lenses": .array(lenses),
        ])
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

    private static func json<T: Encodable>(_ value: T) -> JSONValue {
        guard let data = try? JSONEncoder().encode(value),
            let json = try? JSONDecoder().decode(JSONValue.self, from: data)
        else { return .null }
        return json
    }
}
