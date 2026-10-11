import Foundation

extension WMBridge {
    /// Every bridge operation the wrapper dispatches, by the short
    /// name `resolve` joins to `classPrefix` — the one roster
    /// `make` and the `self_test` probes share (#1889), so an
    /// operation cannot be added without being probed.
    enum Operation: String, CaseIterable, Sendable {
        case copyManagedDisplaySpaces =
            "CopyManagedDisplaySpacesOperation"
        case spaceCopyName = "SpaceCopyNameOperation"
        case spaceCopyValues = "SpaceCopyValuesOperation"
        case copySpacesForWindows = "CopySpacesForWindowsOperation"
        case moveWindowsToManagedSpace =
            "MoveWindowsToManagedSpaceOperation"
        case addWindowsToSpaces = "AddWindowsToSpacesOperation"
        case removeWindowsFromSpaces =
            "RemoveWindowsFromSpacesOperation"
        case managedDisplaySetCurrentSpace =
            "ManagedDisplaySetCurrentSpaceOperation"
        case hideSpaces = "HideSpacesOperation"
        case spaceCreate = "SpaceCreateOperation"
        case spaceDestroy = "SpaceDestroyOperation"
        case spaceSetName = "SpaceSetNameOperation"
        case spaceSetValues = "SpaceSetValuesOperation"

        /// True for an operation that only reads — the ones the
        /// read-only self-test may dispatch.
        var isRead: Bool {
            switch self {
            case .copyManagedDisplaySpaces, .spaceCopyName,
                .spaceCopyValues, .copySpacesForWindows:
                return true
            case .moveWindowsToManagedSpace, .addWindowsToSpaces,
                .removeWindowsFromSpaces,
                .managedDisplaySetCurrentSpace, .hideSpaces,
                .spaceCreate, .spaceDestroy, .spaceSetName,
                .spaceSetValues:
                return false
            }
        }
    }
}
