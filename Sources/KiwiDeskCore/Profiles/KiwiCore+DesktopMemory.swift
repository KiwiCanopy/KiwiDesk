import Foundation

/// The per-Desktop Space memory's reads and writes (#888) —
/// split from `KiwiCore+NativeSpaces.swift` for the file
/// ceiling, the way the event emit already was.
///
/// **Every entry point takes the memory KEY rather than reading
/// it.** A switch handler holds a `DesktopSnapshot` and passes
/// `snapshot.mainUUID`, so the Space a Desktop is remembered
/// under and the Desktop that was authoritative come from one
/// reading of the topology (review round 2, 2026-08-18). Only a
/// caller with no snapshot in hand — a Lua/CLI verb, a test —
/// takes the live convenience below.
extension KiwiCore {
    /// The memory key for a main display, or the `"main"`
    /// sentinel when the topology cannot name one (no SkyLight,
    /// no display-UUID symbol) — so the single-space fallback
    /// still keys deterministically. See `DesktopMemory` for why
    /// the keying is per display and mode-independent.
    static func virtualSpaceMemoryKey(mainUUID: String?) -> String {
        mainUUID ?? "main"
    }

    /// The key for the main display as it is RIGHT NOW — for a
    /// caller holding no snapshot.
    var liveVirtualSpaceMemoryKey: String {
        Self.virtualSpaceMemoryKey(
            mainUUID: NativeSpaces.mainDisplayUUID()
        )
    }

    /// Records the Space the main display's outgoing Desktop was
    /// showing, under `key`.
    func rememberVirtualSpace(
        _ space: SpaceID,
        leaving desktop: Int,
        key: String
    ) {
        desktopMemory
            .virtualSpaces[key, default: [:]][desktop] = space
    }

    /// The Space a native Desktop should show: the one it showed
    /// last under `key`, or the first space as default.
    ///
    /// A remembered SpaceID foreign to the CURRENT space set
    /// falls back too (#888): the binding apply just before this
    /// read may have swapped profiles, and a stale id would
    /// activate a Space the new profile does not have — missing
    /// and stale take the same exit.
    func virtualSpaceTarget(
        for native: Int,
        key: String
    ) -> SpaceID? {
        let spaces = state.workspaces.allSpaces
        if let remembered = desktopMemory.virtualSpaces[key]?[
            native
        ],
            spaces.contains(where: { $0.id == remembered })
        {
            return remembered
        }
        return spaces.first?.id
    }

    /// The live-key convenience, for a caller with no snapshot.
    func rememberVirtualSpace(
        _ space: SpaceID,
        leaving desktop: Int
    ) {
        rememberVirtualSpace(
            space,
            leaving: desktop,
            key: liveVirtualSpaceMemoryKey
        )
    }

    /// The live-key convenience, for a caller with no snapshot.
    func virtualSpaceTarget(for native: Int) -> SpaceID? {
        virtualSpaceTarget(
            for: native,
            key: liveVirtualSpaceMemoryKey
        )
    }
}
