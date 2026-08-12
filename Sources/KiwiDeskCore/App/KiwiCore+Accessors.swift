import Foundation

/// Small read-only accessors split out of `KiwiCore.swift` to
/// keep that file under the size ceiling (AGENTS.md §2) — the
/// flat window/space state reads, plus the computed config/IPC
/// paths (`configURL`, `defaultSocketPath`) the same ceiling
/// pushed out.
extension KiwiCore {
    /// How far the boot has got (#802) — read by the status
    /// mark, the quick menu's count row and the tour's grant
    /// step. `onBootPhaseChange` is the push half; both answer
    /// off the one `BootRun`, so a surface reading late and one
    /// listening cannot disagree.
    public var bootPhase: BootPhase { boot.phase }

    public var onBootPhaseChange: @MainActor (BootPhase) -> Void {
        get { boot.onPhaseChange }
        set { boot.onPhaseChange = newValue }
    }

    public var activeSpace: Space? {
        state.workspaces.activeSpace.flatMap {
            state.workspaces[$0]
        }
    }

    /// The window nearly every implicit-focused command acts on,
    /// and the one the #292 preflight guard vets: the focus ANCHOR
    /// of the active space, not its `space.focused` slot. (`resize`
    /// is the exception — it keeps the local slot to avoid
    /// orphaning id-keyed per-space weights; see `KiwiCore.resize`.)
    /// A
    /// sticky traveler — tiled (#431/#435) or floating (#416) —
    /// can hold the OS focus yet never occupy that
    /// membership-guarded slot, so reading `space.focused` would
    /// target — and let the guard vet — the stale local window
    /// rather than the traveler the user sees focused. Identical
    /// to `space.focused` whenever no traveler is frontmost, so
    /// the common path is unchanged.
    public var focusedWindowID: WindowID? {
        activeSpace.flatMap { state.focusAnchor(of: $0) }
    }

    public var focusedWindow: ManagedWindow? {
        focusedWindowID.flatMap { state.windows[$0] }
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

    public var configURL: URL {
        configDirectory.appendingPathComponent("init.lua")
    }

    /// Where the CLI expects the running app's socket.
    public nonisolated static var defaultSocketPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                ".config/KiwiDesk/KiwiDesk.sock"
            ).path
    }
}
