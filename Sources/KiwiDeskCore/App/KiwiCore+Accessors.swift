import Foundation

/// Small read-only accessors over the flat window/space state,
/// split out of `KiwiCore.swift` to keep that file under the
/// size ceiling (AGENTS.md §2).
extension KiwiCore {
    public var activeSpace: Space? {
        state.workspaces.activeSpace.flatMap {
            state.workspaces[$0]
        }
    }

    public var focusedWindow: ManagedWindow? {
        activeSpace?.focused.flatMap { state.windows[$0] }
    }
}
