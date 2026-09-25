import KiwiDeskCore

/// The Space the add row makes (#1531): the typed name, or — with
/// the field empty — the next number, so a Space needs no name
/// first. nil when the typed name is already a Space.
enum SpaceAddName {
    static func resolve(
        _ typed: String,
        among spaces: [SpaceID]
    ) -> SpaceID? {
        let name = typed.trimmed
        guard name.isEmpty else {
            let id = SpaceID(name)
            return spaces.contains(id) ? nil : id
        }
        return nextNumber(among: spaces)
    }

    /// The count plus one, suffixed ` (1)`, ` (2)`, … while taken.
    static func nextNumber(among spaces: [SpaceID]) -> SpaceID {
        let base = String(spaces.count + 1)
        var candidate = SpaceID(base)
        var suffix = 0
        while spaces.contains(candidate) {
            suffix += 1
            candidate = SpaceID("\(base) (\(suffix))")
        }
        return candidate
    }
}
