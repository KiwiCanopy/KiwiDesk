import KiwiDeskCore

/// What the add row makes of its field (#1531): the typed name,
/// or — with the field empty — `SpaceID.smallestFreeNumber`, so a
/// Space needs no name first; a name another Space holds is
/// refused with the #1623 notice.
enum SpaceAddName: Equatable {
    case add(SpaceID)
    case refused(SpaceNameNotice)

    static func resolve(
        _ typed: String,
        among spaces: [SpaceID]
    ) -> SpaceAddName {
        let name = typed.trimmed
        guard !name.isEmpty else {
            return .add(SpaceID.smallestFreeNumber(among: spaces))
        }
        let id = SpaceID(name)
        return spaces.contains(id) ? .refused(.taken(id.raw)) : .add(id)
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
