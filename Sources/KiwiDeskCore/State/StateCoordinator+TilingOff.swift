import Foundation

/// A Space's tiling toggle (#3008): session state over the
/// start-tiled value, read by every placement decision through
/// `placementMode(of:)` (state-and-layout.md).
extension StateCoordinator {
    // `tilingToggles` (true for on; an absent Space follows
    // `tilingStart`) and `tilingStart`, mirrored in by
    // `KiwiCore.mirrorTilingStart`, are stored on the type.

    /// Whether `space` has tiling off: this session's toggle, else
    /// whether it starts tiled.
    public func isTilingOff(_ space: SpaceID) -> Bool {
        !(tilingToggles[space] ?? tilingStart.startsTiled(space))
    }

    /// The mode `space`'s windows are placed by: Floating while its
    /// tiling is off, its own layout otherwise. Its stored `mode`
    /// never changes, so no Floating gather runs on a toggle.
    public func placementMode(of space: Space) -> LayoutMode {
        isTilingOff(space.id) ? .floating : space.mode
    }

    /// `placementMode(of:)` by id; nil for an unknown Space.
    public func placementMode(of id: SpaceID) -> LayoutMode? {
        workspaces[id].map(placementMode(of:))
    }

    /// Records this session's choice for `space`.
    public mutating func setTiling(_ on: Bool, for space: SpaceID) {
        tilingToggles[space] = on
    }

    /// Carries a renumbered Space's toggle to its new id.
    mutating func rekeyTilingToggle(_ from: SpaceID, to: SpaceID) {
        guard let on = tilingToggles.removeValue(forKey: from) else {
            return
        }
        tilingToggles[to] = on
    }

    /// Forgets a dropped Space's toggle.
    mutating func forgetTilingToggle(of space: SpaceID) {
        tilingToggles[space] = nil
    }
}
