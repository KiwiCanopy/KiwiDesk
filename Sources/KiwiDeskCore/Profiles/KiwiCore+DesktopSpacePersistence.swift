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
        // REPLACE once established, never merge. A merge returns
        // every key absent from live, so a memory the user just
        // discarded is resurrected by the next config load — and
        // the `.number` entries a merge was protecting are the
        // encoder's business already, which is this file's own
        // one-rule-one-place argument.
        if desktopMemory.spaceMemoryEstablished {
            for (key, space) in stored
            where desktopMemory.virtualSpaces[key] == nil
                && key.isIdentity == false
            {
                desktopMemory.virtualSpaces[key] = space
            }
            return
        }
        desktopMemory.virtualSpaces = stored
        desktopMemory.spaceMemoryEstablished = true
    }

    /// Forgets which Space each Desktop was showing (#634).
    ///
    /// A CLEARED memory rather than an absent one: the map became
    /// durable in #1230, so the discard must reach the file, and
    /// only an established memory is stamped into a write.
    func forgetDesktopSpaceMemory() {
        desktopMemory.virtualSpaces = [:]
        desktopMemory.spaceMemoryEstablished = true
    }

    /// Writes the Desktop→Space memory to `gui.json` (#1230).
    ///
    /// Nothing else does at a moment that matters: the eight
    /// sidecar writers are all user actions, so without this the
    /// memory reached disk only if the user happened to save
    /// something after their last swipe. Called at QUIT, where
    /// the session file is already written, and at the discard,
    /// which must not be re-adopted at the next boot.
    ///
    /// **Only where KiwiDesk owns the config.** A Lua-owned setup
    /// has no sidecar to write, so the memory stays session-only
    /// there — a limitation of config ownership rather than a
    /// gap, and `docs/spaces-and-desktops.md` says so.
    func persistDesktopSpaceMemory() {
        guard isGuiManaged, desktopMemory.spaceMemoryEstablished,
            var live = guiConfigStore.load()
        else { return }
        // The STORE, never `saveGuiConfig` — that reloads the
        // whole config, which at quit would rebuild the Lua VM
        // the stop is tearing down. The write-time stamp fills
        // `desktopSpaces` in, so this hands the file back
        // unchanged otherwise.
        // No assignment here: `GuiConfigStore.save` stamps the
        // live memory in, and doing it twice is the two-mechanism
        // shape that produced the restore bug. This site exists
        // for the MOMENT, not for the value.
        do {
            try guiConfigStore.save(live)
        } catch {
            onLog("desktop spaces: write failed: \(error)")
        }
    }
}
