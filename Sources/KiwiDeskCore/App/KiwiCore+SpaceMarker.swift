import Foundation

/// The one derivation of a Space's marker (#1507, #1790): a held
/// Space's or a temporary one's, never both. The Space Bar and
/// KiwiHub's Desktops side (#1229) both read it, so a further
/// Space state joins `SpaceBarItemView.Marker` here once.
extension KiwiCore {
    func spaceMarker(of id: SpaceID) -> SpaceBarItemView.Marker? {
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
