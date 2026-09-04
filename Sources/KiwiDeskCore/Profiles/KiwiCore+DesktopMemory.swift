import Foundation

/// The per-Desktop Space memory's reads and writes (#888) —
/// split from `KiwiCore+Desktops.swift` for the file
/// ceiling, the way the event emit already was.
///
/// **Every entry point takes the Desktop's KEY rather than
/// reading the topology.** A switch handler holds a
/// `DesktopSnapshot` and asks it for the key, so the Space a
/// Desktop is remembered under and the Desktop that was
/// authoritative come from one reading (review round 2,
/// 2026-08-18). Since #1147 that key is the Desktop's own stamp
/// where it carries one, so an entry survives a renumber — which
/// is what the memory was silently losing.
extension KiwiCore {
    /// Records the Space the Desktop being left was showing.
    func rememberVirtualSpace(
        _ space: SpaceID,
        leaving desktop: DesktopKey
    ) {
        desktopMemory.virtualSpaces[desktop] = space
    }

    /// The Space a Desktop should show: the one it showed last,
    /// or the first space as default.
    ///
    /// A remembered SpaceID foreign to the CURRENT space set
    /// falls back too (#888): the binding apply just before this
    /// read may have swapped profiles, and a stale id would
    /// activate a Space the new profile does not have — missing
    /// and stale take the same exit.
    func virtualSpaceTarget(for desktop: DesktopKey) -> SpaceID? {
        let spaces = state.workspaces.allSpaces
        if let remembered = desktopMemory.virtualSpaces[desktop],
            spaces.contains(where: { $0.id == remembered })
        {
            return remembered
        }
        return spaces.first?.id
    }
}
