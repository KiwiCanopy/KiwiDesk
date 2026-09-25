import KiwiDeskCore

/// What the add row makes of its field (#1531): the typed name,
/// or — with the field empty — the next number, so a Space needs
/// no name first; a name another Space holds is refused with the
/// #1623 notice.
enum SpaceAddName: Equatable {
    case add(SpaceID)
    case refused(SpaceNameNotice)

    static func resolve(
        _ typed: String,
        among spaces: [SpaceID]
    ) -> SpaceAddName {
        let name = typed.trimmed
        guard !name.isEmpty else {
            return .add(nextNumber(among: spaces))
        }
        let id = SpaceID(name)
        return spaces.contains(id) ? .refused(.taken(id.raw)) : .add(id)
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

    var space: SpaceID? {
        if case .add(let space) = self { return space }
        return nil
    }

    var notice: SpaceNameNotice? {
        if case .refused(let notice) = self { return notice }
        return nil
    }
}
