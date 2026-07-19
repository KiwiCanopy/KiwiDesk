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

    /// Read-only profile-name availability — the queryable
    /// home of the case-insensitive collision rule (profile
    /// files live on case-insensitive APFS). GUI consumers ask
    /// here; `ProfilesSection.canRename` keeps the one
    /// sanctioned optimistic mirror (review 2026-07), every
    /// further consumer uses this query instead of a copy.
    public func isProfileNameFree(_ name: String) -> Bool {
        !profiles.list().contains {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }
    }
}
