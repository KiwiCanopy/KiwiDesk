import Foundation

/// The Desktop→Space memory's PERSISTENCE (#1230) — split from
/// `KiwiCore+DesktopSpaces.swift` at the §2.1 ceiling along its
/// own subject seam: that file decides which Space a Desktop
/// shows, this one is how the answer outlives the process.
///
/// It rides `gui.json`, so it exists only where KiwiDesk owns
/// the config; a Lua-owned setup keeps the memory session-only.
extension KiwiCore {
    /// The Desktop memory as the FILE should carry it (#1230).
    ///
    /// Read at every sidecar write through
    /// `GuiConfigStore.liveDesktopSpaces`, so a caller handing
    /// back a config it loaded earlier cannot write a stale map
    /// over what the session learned. The `.number` entries are
    /// dropped by the encoder rather than here — one rule, one
    /// place — so this hands over everything.
    func persistedDesktopSpaces() -> [DesktopKey: SpaceID]? {
        guard desktopMemory.spaceMemoryEstablished else {
            return nil
        }
        return desktopMemory.virtualSpaces
    }

    /// Seeds the memory from a loaded config (#1230).
    ///
    /// MERGED, live winning: a reload mid-session must not
    /// discard the `.number` entries this session learned, which
    /// the file never carries.
    func adoptPersistedDesktopSpaces(
        _ stored: [DesktopKey: SpaceID]
    ) {
        desktopMemory.virtualSpaces.merge(stored) { live, _ in
            live
        }
        desktopMemory.spaceMemoryEstablished = true
    }
}
