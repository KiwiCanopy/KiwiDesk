import Foundation

/// The one derivation of a Space's held or temporary state (#1507,
/// #1790), never both. The Space Bar and KiwiHub's Desktops side
/// (#1229) both read it, so a further Space state joins
/// `SpaceBarItemView.SpaceState` here once; tiling off (#3008) is
/// the Space Bar's own wrap around it.
extension KiwiCore {
    func spaceMarker(of id: SpaceID) -> SpaceBarItemView.SpaceState? {
        if let held = state.heldSpaces[id] {
            return .held(
                SpaceBarItemView.Held(
                    screenName: held.screenName,
                    originName: held.name == id ? nil : held.name,
                    profileName: held.arrangement?.profileName
                )
            )
        }
        return isTemporary(id) ? .temporary : nil
    }
}
